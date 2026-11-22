#!/usr/bin/env python3
"""Opt-in usage log hook (ordo plugin): append one JSON line per event to ~/.config/ordo/usage.jsonl.

Off unless a line `ordo usage_log: on` wins (project CLAUDE.md in the payload cwd beats
~/.claude/CLAUDE.md; same line rules as the other switches, read with switch_value() from
guard_bash.py). It is the only switch whose default is off.

Events (see hooks.json), each for the plugin's own skills, agents and scripts only:
SessionStart startup|clear -> start; SessionEnd -> end;
PreToolUse Skill|Agent|Bash|Monitor -> call line; PermissionRequest -> ask line; PermissionDenied -> a line with
result denied (kind skill, agent or script); PostToolUse and PostToolUseFailure of a Skill or an own
script (Bash or Monitor) -> skill or script line with result ok, failed or aborted (is_interrupt true); a Monitor
launch of an own script writes its script line with "via":"monitor" (PostToolUse fires at launch only; no hook reports the end); a failed or
aborted Agent call -> agent line; PostToolUse Agent -> launch line (agent code from tool_response.agentId,
round from "Round N" in the brief); SubagentStart -> agent-start; SubagentStop -> agent line (result ok,
verdict from the first non-blank line of last_assistant_message); PreToolUse Bash -> a guard line (family
only) when the guard is on and guard_bash.check() says the command would be denied.
Own scripts: the fixed list SCRIPTS below; a Bash or Monitor command counts when a pipeline or list segment of its first line
runs that file (in a skill directory under the plugin root) as its first word (optionally behind sh, bash, zsh or python); only the file stem is written.
Fields written, nothing else: time (UTC), kind, name, target (call and ask lines: skill, agent or
script), result (ok, failed, aborted or denied), version, off (switch keys that are off), session,
call, agent (one-way codes: first 12 hex of sha256; the call code is made from session ID, tool
name and the sorted tool input; none of the IDs or inputs is written), round (at most 3 digits),
verdict (one allowed word of code-reviewer, qa or po), family on guard lines and via (only the word monitor, on script lines).
Names are written only when they are on the plugin's own skill, agent or script list. Never written:
error text, reason, is_interrupt, permission suggestions, prompt or reply text, commands, arguments, paths.

Every write takes an exclusive lock on the log directory (about 2 s, then the line is dropped) and removes
.usage-*.tmp files older than a minute. When a line older than 90 days sits in
the first 64 KB of the file (up to 1 MB when that part holds no complete line), the file is rewritten without lines older than 90 days (temp file in the
same directory, then rename) under that lock, so no concurrent line is lost; lines that are not
valid JSON, have no valid time or are dated in the future are kept as they are.

Writes nothing to stdout or stderr and always exits 0: a SessionStart hook's stdout reaches
the model, and a hook bug must never disturb a session. The file is created mode 600 in a
directory created mode 700 and opened without following a symlink.

Standard library only; no network, no spawned processes.
"""
import sys
sys.dont_write_bytecode = True  # importing guard_bash and goal_context must not write a .pyc

import fcntl
import hashlib
import json
import os
import re
import shlex
import stat
import tempfile
import time

EVENTS = ("SessionStart", "SessionEnd", "PreToolUse", "PostToolUse", "PostToolUseFailure", "PermissionRequest",
          "PermissionDenied", "SubagentStart", "SubagentStop")
MAX_STDIN = 8 << 20
PLUGIN_NAME = "ordo"
KEEP_DAYS = 90
HEAD_BYTES = 1 << 16
LINE_CHUNK = 1 << 20
HEAD_MAX = 1 << 20  # read this far when the first 64 KB hold no complete line
STALE_TMP_SECONDS = 60
LOCK_TRIES = 40  # x 50 ms = about 2 s, below the 5 s hook timeout
FAMILIES = ("rebase", "pull-rebase", "force-push", "rm-recursive")
TIME = re.compile(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ")
# the plugin's own scripts: file stem -> file name; a Bash or Monitor command counts only when it runs skills/<skill dir>/<file name> under the plugin root
SCRIPTS = {"stall-check": "stall-check.sh", "usage-report": "usage-report.py"}
INTERPRETERS = ("sh", "bash", "zsh", "python3", "python")
ROUND = re.compile(r"\bRound (\d+)\b")
# first reply line: optional heading marker, optional "Verdict:" label, either may be bold
LEAD = r"(?:#{1,6}[ \t]+)?(?:\*\*)?(?:Verdict(?:\*\*)?:(?:\*\*)?[ \t]*(?:\*\*)?)?"
VERDICTS = {"code-reviewer": ("APPROVED", "CHANGES"), "qa": ("PASS", "FAIL"),
            "po": ("ACCEPTED", "REJECTED", "ESCALATE")}


def plugin_root():
    root = os.environ.get("CLAUDE_PLUGIN_ROOT", "")
    if root and os.path.isabs(root):
        return root
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def own_skills():
    base = os.path.join(plugin_root(), "skills")
    return {d for d in os.listdir(base)
            if re.fullmatch(r"[a-z][a-z0-9-]*", d) and os.path.isfile(os.path.join(base, d, "SKILL.md"))}


def own_agents():
    base = os.path.join(plugin_root(), "agents")
    return {f[:-3] for f in os.listdir(base)
            if f.endswith(".md") and re.fullmatch(r"[a-z][a-z0-9-]*", f[:-3])}


def own_name(value, names):
    """The short name when value is `ordo:<name>` and <name> is on the plugin's own list, else None."""
    prefix = PLUGIN_NAME + ":"
    if isinstance(value, str) and value.startswith(prefix) and value[len(prefix):] in names():
        return value[len(prefix):]
    return None


SEPARATORS = ("|", "||", "&&", ";", "&", "(", ")")


def own_script(command):
    """The file stem when a pipeline or list segment of the command's first line runs an own script as its first
    word (optionally behind sh, bash, zsh or python and its options), else None. Only the first line is parsed,
    so a here-document body is never read."""
    if not isinstance(command, str) or not any(f in command for f in SCRIPTS.values()):
        return None  # cheap exit for every other Bash command
    try:
        lexer = shlex.shlex(command.split("\n")[0], posix=True, punctuation_chars=True)
        lexer.whitespace_split = True
        tokens = list(lexer)
    except ValueError:
        return None
    root = os.path.realpath(plugin_root())
    segment = []
    for token in tokens + [";"]:
        if token not in SEPARATORS:
            segment.append(token)
            continue
        words, segment = segment, []
        if words and os.path.basename(words[0]) in INTERPRETERS:
            words = words[1:]
            while words and words[0].startswith("-"):
                words = words[1:]
        if not words or not os.path.isabs(words[0]):
            continue
        target = os.path.realpath(words[0])
        for stem, fname in SCRIPTS.items():
            if os.path.basename(target) == fname and os.path.dirname(os.path.dirname(target)) == os.path.join(root, "skills"):
                return stem
    return None


def own_call(data):
    """(target, name) for a Skill call of an own skill, an Agent call of an own agent or a Bash or Monitor run of an own script, else None."""
    tool, tool_input = data.get("tool_name"), data.get("tool_input")
    if not isinstance(tool_input, dict):
        return None
    if tool == "Skill":
        name, target = own_name(tool_input.get("skill"), own_skills), "skill"
    elif tool == "Agent":
        name, target = own_name(tool_input.get("subagent_type"), own_agents), "agent"
    elif tool in ("Bash", "Monitor"):
        name, target = own_script(tool_input.get("command")), "script"
    else:
        return None
    return (target, name) if name else None


def verdict_of(message, name):
    """The verdict word of an own review agent: only from the first non-blank line of its final reply."""
    if not isinstance(message, str):
        return None
    first = next((ln for ln in message.split("\n") if ln.strip()), "")
    for word in VERDICTS.get(name, ()):
        if re.match(LEAD + re.escape(word) + r"(?![A-Za-z0-9_-])(?!\s*\|)", first):
            return word
    return None


def round_of(data):
    tool_input = data.get("tool_input")
    brief = tool_input.get("prompt") if isinstance(tool_input, dict) else None
    m = ROUND.search(brief) if isinstance(brief, str) else None
    return int(m.group(1)) if m and len(m.group(1)) <= 3 else None


def plugin_version():
    try:
        with open(os.path.join(plugin_root(), ".claude-plugin", "plugin.json"), "rb") as f:
            v = json.loads(f.read(1 << 16)).get("version")
        return v if isinstance(v, str) and re.fullmatch(r"\d{1,4}\.\d{1,4}\.\d{1,4}", v) else None
    except Exception:
        return None


def digest(text):
    """Short one-way code: first 12 hex of sha256."""
    return hashlib.sha256(text.encode("utf-8", "surrogatepass")).hexdigest()[:12]


def session_code(data):
    sid = data.get("session_id")
    if isinstance(sid, str) and sid:
        return digest(sid)
    return None


def agent_code(agent_id):
    return digest(agent_id) if isinstance(agent_id, str) and agent_id else None


def call_code(data):
    """One-way code of session ID, tool name and the tool input (sorted keys, compact); None without a session ID."""
    sid, tool, tool_input = data.get("session_id"), data.get("tool_name"), data.get("tool_input")
    if not (isinstance(sid, str) and sid and isinstance(tool, str) and isinstance(tool_input, dict)):
        return None
    return digest(sid + "\n" + tool + "\n" + json.dumps(tool_input, sort_keys=True, separators=(",", ":")))


def switch_levels(data):
    levels = []
    cwd = data.get("cwd")
    if isinstance(cwd, str) and os.path.isabs(cwd):
        levels.append(os.path.join(cwd, "CLAUDE.md"))
    home = os.environ.get("HOME", "")
    if home:
        levels.append(os.path.join(home, ".claude", "CLAUDE.md"))
    return levels


def winning(levels, key, switch_value):
    for path in levels:
        value = switch_value(path, key)
        if value:
            return value
    return None


def log_dir():
    home = os.environ.get("HOME", "")
    if not home or not os.path.isabs(home):
        return None
    return os.path.join(home, ".config", "ordo")


def is_old(line, cutoff):
    """True for a complete JSON line whose valid time is before the cutoff; anything else is not old."""
    try:
        t = json.loads(line).get("time")
    except Exception:
        return False
    return isinstance(t, str) and TIME.fullmatch(t) is not None and t < cutoff


def lock(dirfd):
    for _ in range(LOCK_TRIES):
        try:
            fcntl.flock(dirfd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            return True
        except OSError:
            time.sleep(0.05)
    return False


def remove_stale_temp(d):
    """Remove .usage-*.tmp files older than a minute (left by a killed prune). Caller holds the lock."""
    limit = time.time() - STALE_TMP_SECONDS
    try:
        names = os.listdir(d)
    except OSError:
        return
    for n in names:
        if n.startswith(".usage-") and n.endswith(".tmp"):
            p = os.path.join(d, n)
            try:
                st = os.lstat(p)
                if stat.S_ISREG(st.st_mode) and st.st_mtime < limit:
                    os.unlink(p)
            except OSError:
                pass


def prune(d, path):
    """Rewrite the log without lines older than KEEP_DAYS; only when one shows up in the head. Caller holds the lock."""
    cutoff = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() - KEEP_DAYS * 86400))
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    except OSError:
        return
    with os.fdopen(fd, "rb") as src:
        if not stat.S_ISREG(os.fstat(src.fileno()).st_mode):
            return
        head = src.read(HEAD_BYTES)
        if len(head) == HEAD_BYTES:
            if b"\n" not in head:
                head += src.read(HEAD_MAX - HEAD_BYTES)
            head = head[:head.rfind(b"\n") + 1]
        if not any(is_old(line, cutoff) for line in head.split(b"\n")):
            return
        src.seek(0)
        tmpfd, tmp = tempfile.mkstemp(prefix=".usage-", suffix=".tmp", dir=d)  # created mode 600
        try:
            with os.fdopen(tmpfd, "wb") as dst:
                while True:
                    chunk = src.readline(LINE_CHUNK)
                    if not chunk:
                        break
                    if not (chunk.endswith(b"\n") and is_old(chunk, cutoff)):
                        dst.write(chunk)
            os.replace(tmp, path)
        except BaseException:
            try:
                os.unlink(tmp)
            except OSError:
                pass
            raise


def append_line(record):
    d = log_dir()
    if d is None:
        return
    if os.path.islink(d):
        return
    os.makedirs(d, mode=0o700, exist_ok=True)
    dirfd = os.open(d, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        if not lock(dirfd):
            return
        path = os.path.join(d, "usage.jsonl")
        remove_stale_temp(d)
        prune(d, path)
        fd = os.open(path, os.O_RDWR | os.O_APPEND | os.O_CREAT | os.O_NOFOLLOW | os.O_NONBLOCK, 0o600)
        try:
            st = os.fstat(fd)
            if not stat.S_ISREG(st.st_mode):
                return
            if stat.S_IMODE(st.st_mode) != 0o600:
                os.fchmod(fd, 0o600)
            line = (json.dumps(record, separators=(",", ":")) + "\n").encode("ascii")
            if st.st_size and os.pread(fd, 1, st.st_size - 1) != b"\n":
                line = b"\n" + line  # a half-written last line must not swallow this one
            os.write(fd, line)
        finally:
            os.close(fd)
    finally:
        os.close(dirfd)


def now():
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def add_common(record, levels, switch_value):
    from goal_context import SWITCH_KEYS
    version = plugin_version()
    if version:
        record["version"] = version
    record["off"] = [k for k in SWITCH_KEYS if winning(levels, k, switch_value) == "off"]


def outcome(data, event):
    """PostToolUse: ok (a Skill call only when tool_response.success is true, else failed); PostToolUseFailure:
    aborted when is_interrupt is true, else failed."""
    if event == "PostToolUse":
        response = data.get("tool_response")
        if data.get("tool_name") == "Skill" and not (isinstance(response, dict) and response.get("success") is True):
            return "failed"
        return "ok"
    return "aborted" if data.get("is_interrupt") is True else "failed"


def handle(data):
    event = data.get("hook_event_name")
    if event not in EVENTS:
        return
    from guard_bash import switch_value
    levels = switch_levels(data)
    if winning(levels, "usage_log", switch_value) != "on":
        return
    session = session_code(data)
    record = {"time": now()}
    if event in ("SessionStart", "SessionEnd"):
        if event == "SessionStart" and data.get("source") not in ("startup", "clear"):
            return
        record["kind"] = "start" if event == "SessionStart" else "end"
    elif event in ("SubagentStart", "SubagentStop"):
        name = own_name(data.get("agent_type"), own_agents)
        code = agent_code(data.get("agent_id"))
        if name is None or (event == "SubagentStart" and code is None):
            return
        if event == "SubagentStart":
            record.update(kind="agent-start", name=name, agent=code)
        else:
            record.update(kind="agent", name=name, result="ok")
            add_common(record, levels, switch_value)
            if code:
                record["agent"] = code
            verdict = verdict_of(data.get("last_assistant_message"), name)
            if verdict:
                record["verdict"] = verdict
    elif event == "PostToolUse" and data.get("tool_name") == "Agent":
        tool_input = data.get("tool_input")
        response = data.get("tool_response")
        name = (own_name(response.get("agentType") if isinstance(response, dict) else None, own_agents)
                or own_name(tool_input.get("subagent_type") if isinstance(tool_input, dict) else None, own_agents))
        if name is None:
            return
        record["kind"] = "launch"
        code = agent_code(response.get("agentId") if isinstance(response, dict) else None)
        if code:
            record["agent"] = code
        rnd = round_of(data)
        if rnd is not None:
            record["round"] = rnd
    else:
        if event == "PreToolUse" and data.get("tool_name") == "Bash":
            tool_input = data.get("tool_input")
            command = tool_input.get("command") if isinstance(tool_input, dict) else None
            if isinstance(command, str):
                from guard_bash import check, guard_is_off
                family = check(command)
                if family in FAMILIES and not guard_is_off(data.get("cwd")):
                    record.update(kind="guard", family=family)
                    if session:
                        record["session"] = session
                    append_line(record)
                    return
        found = own_call(data)
        if found is None:
            return
        target, name = found
        if event == "PreToolUse":
            record.update(kind="call", target=target, name=name)
        elif event == "PermissionRequest":
            record.update(kind="ask", target=target, name=name)
            add_common(record, levels, switch_value)
        else:  # PostToolUse, PostToolUseFailure, PermissionDenied
            record.update(kind=target, name=name, result="denied" if event == "PermissionDenied" else outcome(data, event))
            if data.get("tool_name") == "Monitor" and event != "PermissionDenied":
                record["via"] = "monitor"
            add_common(record, levels, switch_value)
    if session:
        record["session"] = session
        code = call_code(data)
        if code and record["kind"] in ("skill", "agent", "script", "ask", "call", "launch"):
            record["call"] = code
    append_line(record)


def main():
    raw = sys.stdin.buffer.read(MAX_STDIN + 1)
    if len(raw) > MAX_STDIN:
        return
    data = json.loads(raw)
    if isinstance(data, dict):
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        handle(data)


if __name__ == "__main__":
    try:
        main()
    except BaseException:  # fail open and silent
        pass
    sys.exit(0)
