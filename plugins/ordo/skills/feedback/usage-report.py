#!/usr/bin/env python3
"""Helper of the ordo:feedback skill. Standard library only; no network, no spawned processes.

  switch               `usage_log: on` or `usage_log: off` (same rules as the hook)
  summary [--days N]   counts from ~/.config/ordo/usage.jsonl for the last N days (default 30, at most 90): per own skill, agent and
                       script the runs, failed, aborted, asked, ran, not allowed, denied (auto mode) and cancelled numbers (agents also started,
                       never finished; a script also started through Monitor, when it was), verdict and guard counts, agent run time and session length
  settings             one line per switch (13) and per value setting (9): value and level (project, global or default),
                       read from ./CLAUDE.md and ~/.claude/CLAUDE.md with the rules of the hooks; never a file path
  redact               stdin to stdout: paths, e-mail addresses and private terms replaced by [removed]; when the
                       private-terms list (~/.config/ordo/private-terms.txt) cannot be used, the first output line is
                       `ordo-redact-note: ...` (the caller shows it to the user and drops it from the text)
  clear-info           show what `clear` would delete (path, number of lines, period)
  clear --yes          delete ~/.config/ordo/usage.jsonl and nothing else

summary prints only words from fixed allow-lists (the plugin's own skill, agent and script names, verdict words, guard
families) and numbers; anything else in a line is skipped and never printed. Session, agent and call codes are used to pair
lines (start with end, ask with outcome, call with outcome, agent start with finish) and are never printed. A line with no
result counts in nothing.
Reading is bounded (the last 8 MB of the file). Nothing is written by summary, settings, redact or clear-info.
"""
import sys
sys.dont_write_bytecode = True

import os
import re
import stat
from datetime import datetime, timezone

MAX_DAYS = 90
DEFAULT_DAYS = 30
MAX_READ = 8 << 20
MAX_LINE = 4096
MAX_SECONDS = 10_000_000
MAX_TEXT = 2 << 20
MAX_TERMS = 1 << 20
MARKER = "[removed]"
NOTE = "ordo-redact-note: private-terms list not used (%s); paths and e-mail addresses were still removed"
FAMILIES = ("rebase", "pull-rebase", "force-push", "rm-recursive")
VERDICTS = {"code-reviewer": ("APPROVED", "CHANGES"), "qa": ("PASS", "FAIL"),
            "po": ("ACCEPTED", "REJECTED", "ESCALATE")}
TIME = re.compile(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ")
NAME = re.compile(r"[a-z][a-z0-9-]*")
HOOKS = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "hooks")


class Fail(Exception):
    pass


def log_path():
    home = os.environ.get("HOME", "")
    if not home or not os.path.isabs(home):
        raise Fail("cannot find the usage file: HOME is not set")
    return os.path.join(home, ".config", "ordo", "usage.jsonl")


def own_names():
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    skills = {d for d in os.listdir(os.path.join(root, "skills"))
              if NAME.fullmatch(d) and os.path.isfile(os.path.join(root, "skills", d, "SKILL.md"))}
    agents = {f[:-3] for f in os.listdir(os.path.join(root, "agents"))
              if f.endswith(".md") and NAME.fullmatch(f[:-3])}
    return skills, agents


def open_log(path):
    """Open the log for reading without following a symlink; None when it is missing or not a regular file."""
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    except OSError:
        return None
    f = os.fdopen(fd, "rb")
    if not stat.S_ISREG(os.fstat(f.fileno()).st_mode):
        f.close()
        return None
    return f


def parse_time(value):
    if not isinstance(value, str) or not TIME.fullmatch(value):
        return None
    try:
        return datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    except ValueError:
        return None


def tail_lines(f):
    size = os.fstat(f.fileno()).st_size
    start = max(0, size - MAX_READ)
    f.seek(start)
    data = f.read(MAX_READ)
    lines = data.split(b"\n")
    if start:
        lines = lines[1:]  # the first line of a cut read is partial
    return lines


def ranked(counter):
    return sorted(counter.items(), key=lambda kv: (-kv[1], kv[0]))


def own_scripts():
    """The stems of the plugin's own scripts: the fixed list SCRIPTS of the usage hook, which writes the lines."""
    sys.path.insert(0, HOOKS)
    from usage_log import SCRIPTS
    return set(SCRIPTS)


def code_of(value):
    return value if isinstance(value, str) and 0 < len(value) <= 64 else None


class Stats:
    """Counts per name for one target (skill, agent or script)."""
    FIELDS = ("runs", "failed", "aborted", "asked", "ran", "denied", "cancelled", "never", "monitor")

    def __init__(self):
        self.names = {}

    def add(self, name, field, n=1):
        self.names.setdefault(name, dict.fromkeys(self.FIELDS, 0))[field] += n


def fmt_stats(label, stats, agent):
    rows = sorted(stats.names.items(), key=lambda kv: (-kv[1]["runs"], kv[0]))
    if not rows:
        return ["%s: none" % label]
    out = [label + ":"]
    for name, c in rows:
        line = "  %s: runs %d, failed %d, aborted %d, asked %d, ran %d, not allowed %d, denied (auto mode) %d, cancelled (by you, or the session ended) %d" % (
            name, c["runs"], c["failed"], c["aborted"], c["asked"], c["ran"], c["asked"] - c["ran"], c["denied"], c["cancelled"])
        if agent:
            line += ", started, never finished %d" % c["never"]
        if c["monitor"]:
            line += ", started through Monitor %d (outcome not reported)" % c["monitor"]
        out.append(line)
    return out


def summary(days):
    import json
    now = datetime.now(timezone.utc)
    since = datetime.fromtimestamp(now.timestamp() - days * 86400, timezone.utc)
    skills_ok, agents_ok = own_names()
    own = {"skill": skills_ok, "agent": agents_ok, "script": own_scripts()}
    stats = {t: Stats() for t in own}
    verdicts, guards = {}, {}
    secs, starts, agent_runs, anonymous = {}, {}, {}, []
    agent_time, agent_meta, launched, failed_calls, idx = {}, {}, set(), [], 0
    open_asks, open_calls = {}, {}  # per call code: names of asks and of calls still waiting for an outcome
    open_at, lengths = {}, []

    def outcome(code):
        """A run line, a launch line or a failed or aborted Agent call line settles one ask, else one call, of that code."""
        if code is None:
            return
        asks, calls = open_asks.get(code), open_calls.get(code)
        if asks:
            target, name = asks.pop(0)
            stats[target].add(name, "ran")
        elif calls:
            calls.pop(0)

    f = open_log(log_path())
    if f is not None:
        with f:
            for raw in tail_lines(f):
                if not raw.strip() or len(raw) > MAX_LINE:
                    continue
                try:
                    rec = json.loads(raw.decode("utf-8"))
                except Exception:
                    continue
                if not isinstance(rec, dict):
                    continue
                t = parse_time(rec.get("time"))
                if t is None or t < since or t > now:
                    continue
                idx += 1
                kind, name, result, target = rec.get("kind"), rec.get("name"), rec.get("result"), rec.get("target")
                code, call, agent = code_of(rec.get("session")), code_of(rec.get("call")), code_of(rec.get("agent"))
                if kind in ("start", "end") and code:
                    if kind == "start":
                        open_at.setdefault(code, []).append(t)  # a same-code /clear start waits behind the earlier one
                    elif open_at.get(code):
                        d = (t - open_at[code].pop(0)).total_seconds()
                        if 0 <= d <= MAX_SECONDS:
                            lengths.append(d)
                elif kind == "guard" and rec.get("family") in FAMILIES:
                    guards[rec["family"]] = guards.get(rec["family"], 0) + 1
                elif kind == "launch":
                    if agent:
                        launched.add(agent)
                    outcome(call)
                elif kind in ("call", "ask") and target in own and isinstance(name, str) and name in own[target]:
                    if kind == "ask":
                        stats[target].add(name, "asked")
                        if call:
                            open_asks.setdefault(call, []).append((target, name))
                            if open_calls.get(call):
                                open_calls[call].pop(0)  # an ask covers the call that came before it
                    elif call:
                        open_calls.setdefault(call, []).append((target, name))
                elif kind == "agent-start" and agent and isinstance(name, str) and name in agents_ok:
                    starts.setdefault(agent, []).append((name, t))
                    agent_meta.setdefault(agent, (name, code, idx))
                elif kind in own and isinstance(name, str) and name in own[kind] and result in ("ok", "failed", "aborted", "denied"):
                    if result == "denied":
                        stats[kind].add(name, "denied")  # its own count: not a run, not asked, not not-allowed
                        asks = open_asks.get(call)
                        if asks:
                            atarget, aname = asks.pop(0)  # the denial settles the earlier ask: the call is counted once, as denied
                            stats[atarget].add(aname, "asked", -1)
                        elif open_calls.get(call):
                            open_calls[call].pop(0)  # a denied call is never cancelled
                        continue
                    if kind == "agent":
                        v = rec.get("verdict")
                        v = v if isinstance(v, str) and v in VERDICTS.get(name, ()) else None
                        if agent:
                            run = agent_runs.setdefault(agent, [name, "ok", None])
                            if result != "ok":
                                run[1] = result
                            run[2] = run[2] or v
                            if starts.get(agent):
                                sname, st = starts[agent].pop(0)
                                d = (t - st).total_seconds()
                                if 0 <= d <= MAX_SECONDS:
                                    agent_time[agent] = (sname, agent_time.get(agent, (sname, 0))[1] + int(d))
                        elif result != "ok":
                            failed_calls.append((idx, name, result, code))  # the hook writes it with no agent code
                        else:
                            anonymous.append((name, result, v))
                        if result != "ok":
                            outcome(call)  # a failed or aborted Agent call is the outcome of that call
                    else:
                        stats[kind].add(name, "runs")
                        if result != "ok":
                            stats[kind].add(name, result)
                        if kind == "script" and rec.get("via") == "monitor":
                            stats[kind].add(name, "monitor")  # a launch: Claude Code sends no hook when a Monitor ends
                        outcome(call)
    # a failed or aborted Agent call is the call of the oldest unclaimed agent of the same session and name that has a
    # finish, no launch line and a start before the failed line (first in, first out); with none it stays one run
    claimed = set()
    for fidx, fname, fresult, fcode in failed_calls:
        for acode, (aname, acode_session, sidx) in sorted(agent_meta.items(), key=lambda kv: kv[1][2]):
            if (acode not in claimed and acode in agent_runs and acode not in launched and aname == fname
                    and fcode and acode_session == fcode and sidx < fidx):
                claimed.add(acode)
                agent_runs[acode][1] = fresult
                break
        else:
            anonymous.append((fname, fresult, None))
    for sname, total in agent_time.values():
        secs.setdefault(sname, []).append(total)
    for name, result, v in anonymous + [tuple(r) for r in agent_runs.values()]:
        stats["agent"].add(name, "runs")
        if result != "ok":
            stats["agent"].add(name, result)
        if v:
            verdicts[v] = verdicts.get(v, 0) + 1
    for calls in open_calls.values():
        for target, name in calls:
            stats[target].add(name, "cancelled")
    for pending in starts.values():
        for name, _ in pending:
            stats["agent"].add(name, "never")
    if not (any(s.names for s in stats.values()) or guards or lengths):
        return ["No usage recorded in the last %d days." % days]

    def fmt(label, counts):
        return "%s: %s" % (label, ", ".join("%s %d" % kv for kv in ranked(counts)) or "none")

    if secs:
        run = "Agent run time: " + "; ".join(
            "%s total %d s, average %d s over %d run%s" % (n, sum(v), int(sum(v) / len(v) + 0.5), len(v), "" if len(v) == 1 else "s")
            for n, v in sorted(secs.items(), key=lambda kv: (-sum(kv[1]), kv[0])))
    else:
        run = "Agent run time: no times recorded"
    def minutes(sec):
        m = int(sec / 60 + 0.5)
        return "%d min" % m if m < 60 else "%d:%02d h" % (m // 60, m % 60)

    if lengths:
        length = "Session length: total %s, average %s over %d session%s" % (
            minutes(sum(lengths)), minutes(sum(lengths) / len(lengths)), len(lengths), "" if len(lengths) == 1 else "s")
    else:
        length = "Session length: no session has a length"
    return (["Usage summary, last %d days (UTC %s to %s)" % (days, since.strftime("%Y-%m-%d"), now.strftime("%Y-%m-%d"))]
            + fmt_stats("Skills", stats["skill"], False) + fmt_stats("Agents", stats["agent"], True)
            + fmt_stats("Scripts", stats["script"], False)
            + [fmt("Verdicts", verdicts), fmt("Guard blocks", guards), run, length])


# --- redaction. A folder name in the middle of a path may hold up to eight words separated by single spaces.
def _mid(stop):
    w = r"[^%s\s\"'`<>|]+" % stop
    return w + r"(?: " + w + r"){0,7}"


def _seg(stop):
    return r"[^%s\s\"'`<>|()\[\]{},;]*" % stop


_UNIX_TAIL = r"(?:/%s(?=/))*/%s" % (_mid("/:"), _seg("/:"))
_WIN_TAIL = r"(?:%s[\\/])*%s" % (_mid(r"\\/:*?"), _seg(r"\\/:*?"))
_ROOTS = "tmp|etc|usr|var|opt|home|Users|root|mnt|srv|bin|sbin|lib|dev|proc|sys|private|Volumes|Library|Applications|System"
# an absolute path may start after a space or bracket, after a colon (not the // of a URL), after a flag letter (-I/...)
_ABS_START = r"(?:(?<![\w.:/\\)\]~-])|(?<=(?<!\w)-[A-Za-z])|(?<=:)(?!//))"
PATHS = re.compile("|".join([
    r"(?<![A-Za-z0-9])(?i:file:/|[a-z][a-z0-9+.-]*://file/)[^\s\"'`<>)\]]*",          # file URL, file:/..., scheme://file/...
    r"(?<![\\\w])\\\\\?\\[A-Za-z]:[\\/]" + _WIN_TAIL,                              # \\?\C:\... long path
    r"(?<![\\\w])\\\\[^\s\\/\"'`<>|]+(?:\\%s(?=\\))*(?:\\%s)?" % (_mid(r"\\/:*?"), _seg(r"\\/:*?")),   # UNC
    r"(?<![A-Za-z0-9])[A-Za-z]:[\\/]" + _WIN_TAIL,                                        # Windows drive
    r"(?<![\w~])~(?:[A-Za-z_][A-Za-z0-9._-]*(?:%s)?|%s)" % (_UNIX_TAIL, _UNIX_TAIL),  # ~user, ~/...
    _ABS_START + r"(?:(?:/%s(?=/))+/%s|/(?:%s)(?![\w./-]))" % (_mid("/:"), _seg("/:"), _ROOTS),  # absolute path
    r"(?<=[\w.-])/(?:Users|home)(?:/%s(?=/))*/%s" % (_mid("/:"), _seg("/:")),         # x/Users/...
    r"[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}",             # e-mail
]))


def load_terms():
    """(terms, None) or (None, reason): the terms list is read with the same rules in every tool: CRLF, blank lines and padding."""
    home = os.environ.get("HOME", "")
    if not home or not os.path.isabs(home):
        return None, "HOME is not set"
    path = os.path.join(home, ".config", "ordo", "private-terms.txt")
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
    except FileNotFoundError:
        return None, "missing"
    except OSError:
        return None, "unreadable"
    try:
        with os.fdopen(fd, "rb") as f:
            if not stat.S_ISREG(os.fstat(f.fileno()).st_mode):
                return None, "unreadable"
            data = f.read(MAX_TERMS + 1)
    except OSError:
        return None, "unreadable"
    if len(data) > MAX_TERMS:
        return None, "too large"
    if b"\0" in data:
        return None, "NUL byte"
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        return None, "not UTF-8"
    terms = [t for t in (ln.strip(" \t\n\v\f") for ln in text.replace("\r", "").split("\n")) if t]
    return (terms, None) if terms else (None, "empty")


def redact(text, terms):
    pattern = None
    if terms:
        # a lookahead finds a match at every start position, so partly overlapping terms are all found
        pattern = re.compile("(?=(%s))" % "|".join(re.escape(t) for t in sorted(set(terms), key=len, reverse=True)), re.IGNORECASE)
    parts = []
    for piece in text.split(MARKER):  # a marker already in the text stays as it is
        spans = [m.span() for m in PATHS.finditer(piece)]
        if pattern:
            spans += [m.span(1) for m in pattern.finditer(piece)]
        out, pos = [], 0
        merged = []
        for a, b in sorted(spans):
            if merged and a <= merged[-1][1]:
                merged[-1][1] = max(merged[-1][1], b)
            else:
                merged.append([a, b])
        for a, b in merged:
            out.append(piece[pos:a])
            out.append(MARKER)
            pos = b
        out.append(piece[pos:])
        parts.append("".join(out))
    return MARKER.join(parts)


def usage_switch():
    """'on' or 'off' for usage_log: the same rules and the same reader as the hook (switch_value of guard_bash.py)."""
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "hooks"))
    from guard_bash import switch_value
    levels = [os.path.join(os.getcwd(), "CLAUDE.md")]
    home = os.environ.get("HOME", "")
    if home and os.path.isabs(home):
        levels.append(os.path.join(home, ".claude", "CLAUDE.md"))
    for path in levels:
        if switch_value(path, "usage_log"):
            return "usage_log: " + switch_value(path, "usage_log")
    return "usage_log: off"


# the settings that hold a value: key -> (accepted form, default); the number keys take a positive integer
VALUE_SETTINGS = (("watch_check_minutes", "number", "5"), ("watch_report_minutes", "number", "10"),
                  ("watch_check_by", "script|model", "script"), ("reader_threshold_tokens", "number", "200000"),
                  ("reader_threshold_files", "number", "10"), ("reader_cap_tokens", "number", "80000"),
                  ("reader_cap_files", "number", "10"), ("addon_max_lines", "number", "40"),
                  ("addon_scope", "global|project|ask", "global"))


def setting_value(path, key, form, max_bytes):
    """The value of the last valid `ordo <key>: <value>` line of the file, else None (also on any read error).
    Read like switch_value() of guard_bash.py: regular file only, at most 1 MB, UTF-8, surrounding space and CR allowed."""
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
        try:
            if not stat.S_ISREG(os.fstat(fd).st_mode):
                return None
            with os.fdopen(fd, "rb", closefd=False) as f:
                data = f.read(max_bytes + 1)
        finally:
            os.close(fd)
        if len(data) > max_bytes:
            return None
        text = data.decode("utf-8-sig")
    except (OSError, UnicodeDecodeError):
        return None
    value = None
    for line in text.split("\n"):
        m = re.fullmatch(r"ordo %s: (\S+)" % re.escape(key), line.strip())
        if not m:
            continue
        v = m.group(1)
        if form == "number" and re.fullmatch(r"[0-9]+", v) and len(v) <= 18 and int(v) > 0:
            value = str(int(v))
        elif form != "number" and v in form.split("|"):
            value = v
    return value


def settings():
    """One line per setting: `- <key>: <value> (project|global|default)`; level names only, never a path."""
    sys.path.insert(0, HOOKS)
    from guard_bash import switch_value, MAX_SWITCH_FILE
    from goal_context import SWITCH_KEYS
    levels = [("project", os.path.join(os.getcwd(), "CLAUDE.md"))]
    home = os.environ.get("HOME", "")
    if home and os.path.isabs(home):
        levels.append(("global", os.path.join(home, ".claude", "CLAUDE.md")))
    out = []
    for key in SWITCH_KEYS + ("usage_log",):
        value, where = "off" if key == "usage_log" else "on", "default"
        for level, path in levels:
            v = switch_value(path, key)
            if v:
                value, where = v, level
                break
        out.append("- %s: %s (%s)" % (key, value, where))
    for key, form, default in VALUE_SETTINGS:
        value, where = default, "default"
        for level, path in levels:
            v = setting_value(path, key, form, MAX_SWITCH_FILE)
            if v:
                value, where = v, level
                break
        out.append("- %s: %s (%s)" % (key, value, where))
    return out


def nothing(path):
    return "Nothing to delete: %s is missing or empty." % path


def lines_and_period(f):
    """Number of lines and the oldest and newest valid time in a log, read in bounded pieces."""
    count, first, last, cont = 0, None, None, False
    while True:
        chunk = f.readline(MAX_LINE + 1)
        if not chunk:
            break
        whole = chunk.endswith(b"\n")
        if not cont and chunk.strip():
            count += 1
            m = re.search(rb'"time":"(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ)"', chunk)
            if m and parse_time(m.group(1).decode("ascii")) is not None:
                t = m.group(1).decode("ascii")
                first = t if first is None or t < first else first
                last = t if last is None or t > last else last
        cont = not whole
    return count, first, last


def checked_log():
    """(path, file or None); refuses a symlink, a directory or any other non-regular file at the path."""
    path = log_path()
    try:
        st = os.lstat(path)
    except FileNotFoundError:
        return path, None
    except OSError:
        raise Fail("cannot read the usage file")
    if not stat.S_ISREG(st.st_mode):
        raise Fail("the usage file path is not a regular file; nothing was changed")
    return path, open_log(path)


def clear_info():
    path, f = checked_log()
    if f is None:
        return [nothing(path)]
    with f:
        count, first, last = lines_and_period(f)
    if count == 0:
        return [nothing(path)]
    return ["File: %s" % path, "Lines: %d" % count, "Period: %s to %s" % (first or "unknown", last or "unknown")]


def clear():
    path, f = checked_log()
    if f is None:
        return [nothing(path)]
    with f:
        count = lines_and_period(f)[0]
    if count == 0:
        return [nothing(path)]
    try:
        os.unlink(path)
    except OSError:
        raise Fail("could not delete the usage file; nothing was changed")
    return ["Deleted %s (%d lines)." % (path, count)]


def parse_days(args):
    if not args:
        return DEFAULT_DAYS
    if len(args) != 2 or args[0] != "--days" or not re.fullmatch(r"[0-9]{1,3}", args[1]):
        raise Fail("usage: summary [--days N] with N a whole number from 1 to %d" % MAX_DAYS)
    n = int(args[1])
    if not 1 <= n <= MAX_DAYS:
        raise Fail("days must be from 1 to %d" % MAX_DAYS)
    return n


def main(argv):
    if not argv:
        raise Fail("usage: usage-report.py summary|settings|redact|clear-info|clear --yes")
    cmd, rest = argv[0], argv[1:]
    if cmd == "summary":
        print("\n".join(summary(parse_days(rest))))
    elif cmd == "switch" and not rest:
        print(usage_switch())
    elif cmd == "settings" and not rest:
        print("\n".join(settings()))
    elif cmd == "clear-info" and not rest:
        print("\n".join(clear_info()))
    elif cmd == "clear" and rest == ["--yes"]:
        print("\n".join(clear()))
    elif cmd == "redact" and not rest:
        raw = sys.stdin.buffer.read(MAX_TEXT + 1)
        if len(raw) > MAX_TEXT:
            raise Fail("text is too long to redact")
        terms, reason = load_terms()
        text = redact(raw.decode("utf-8", "surrogateescape"), terms)
        if terms is None:
            text = NOTE % reason + "\n" + text
        sys.stdout.buffer.write(text.encode("utf-8", "surrogateescape"))
    elif cmd == "clear":
        raise Fail("clear needs --yes, which is given only after the user's yes; nothing was deleted")
    else:
        raise Fail("unknown command")


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except Fail as e:
        sys.stderr.write("usage-report: %s\n" % e)
        sys.exit(2)
    except OSError:
        sys.stderr.write("usage-report: a file could not be read or written\n")
        sys.exit(2)
