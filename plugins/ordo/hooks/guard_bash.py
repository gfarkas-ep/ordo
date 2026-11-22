#!/usr/bin/env python3
"""PreToolUse guard for the Bash tool (ordo plugin).

Hard-denies four command families, nothing else:
  rebase          any `git rebase` form
  pull-rebase     `git pull --rebase`, `-r`, `--rebase=...`
  force-push      `git push` with --force, a short cluster containing f,
                  --force-with-lease[=...], --force-if-includes, or a +refspec
  rm-recursive    `rm` with a recursive flag and a target of exactly /, /*, ~, ~/,
                  ~/*, $HOME, ${HOME} (each with optional / or /*) or the HOME path

Reads the PreToolUse JSON on stdin. Deny: JSON on stdout, exit 0. Allow: no
stdout, exit 0. Every error path fails open (exit 0, empty stdout, warning on
stderr); it never exits 2, which would block.

Matching is on argv. Unquoted `#` comments and heredoc bodies are text, not
commands, and are skipped; a heredoc fed to bash|sh|zsh (`bash <<EOF`, `<<EOF | bash`, or a
`bash -c "$(cat <<EOF`) is executed, so its body is checked as a command. The command is split on unquoted ; && || | & ( ) ` and
newline. Prefixes sudo, env, K=V, `git -C/-c ...`, the keywords { ! do then else
elif if while until, and time, nohup, timeout, nice are looked through, and
`bash|sh|zsh -c <string>` is parsed recursively up to 3 levels deep. A string
nested deeper than that, or one that cannot be tokenised (unclosed quote), gets a
raw-string regex scan for the same four families instead.
Not inspected: eval, shell variables, scripts on disk, config-driven pull.rebase,
command substitution inside double quotes, env -S, command/exec/xargs/find -exec.

Switch: a line `ordo guard_hook: off` (exactly that, lower-case, surrounding
whitespace and CRLF allowed; `on` likewise; any other line is ignored; the last
valid line in a file wins) in <payload cwd>/CLAUDE.md, else in $HOME/.claude/CLAUDE.md,
lets every command through. The project file beats the global one; default on.
The two files are read only after a command matched a deny family. A file that is
missing, unreadable, not UTF-8, over 1 MB or not a regular file (directory, FIFO, device), and a cwd that is missing, not a
string or not absolute, make that level silent; such an error never reaches the
fail-open path in main(): the command is denied as without the switch.

Standard library only; no file writes, no network, no subprocess.
"""
import json
import os
import re
import stat
import sys

MAX_DEPTH = 3
MAX_SWITCH_FILE = 1 << 20  # a CLAUDE.md over 1 MB is not read: that level is silent
PUNCT = ";&|()`\n"
SEP = None  # token for an unquoted command separator
ENV_ASSIGN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
SUDO_ARG_OPTS = {"-u", "-g", "-h", "-p", "-C", "-D", "-R", "-T", "-r", "-t", "-U",
                 "--user", "--group", "--host", "--prompt", "--chdir", "--role", "--type"}
KEYWORDS = {"{", "!", "do", "then", "else", "elif", "if", "while", "until"}
TIMEOUT_ARG_OPTS = {"-k", "-s", "--kill-after", "--signal"}
NICE_ARG_OPTS = {"-n", "--adjustment"}
HEREDOC = re.compile(r"""<<(-?)\s*(?:'([^'\n]+)'|"([^"\n]+)"|\\?([A-Za-z_][A-Za-z0-9_]*))""")
SHELL_BEFORE = re.compile(r"(?:^|[;&|(`\s/])(?:bash|sh|zsh)(?:\s+-\S+)*\s*$")
SHELL_C_BEFORE = re.compile(r"(?:^|[;&|(`\s/])(?:bash|sh|zsh)\s+(?:-\S+\s+)*-[A-Za-z]*c\b")
PIPE_TO_SHELL = re.compile(r"\|\s*(?:sudo\s+)?(?:\S*/)?(?:bash|sh|zsh)\b")
ENV_ARG_OPTS = {"-u", "-C", "-S", "--unset", "--chdir", "--split-string"}
GIT_ARG_OPTS = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--config-env"}
SHELL_C = re.compile(r"^-[A-Za-z]*c[A-Za-z]*$")
PULL_R = re.compile(r"^-[qvnpafdtk46]*r[qvnpafdtk46]*$")
SHORT_F = re.compile(r"^-[A-Za-z0-9]*f[A-Za-z0-9]*$")
RM_FIXED = ("/", "/*", "~", "~/", "~/*", "$HOME", "${HOME}", "$HOME/", "$HOME/*",
            "${HOME}/", "${HOME}/*")


def home_targets():
    home = os.environ.get("HOME", "").rstrip("/")
    return (home, home + "/", home + "/*") if home else ()


def is_danger_target(t):
    return t in RM_FIXED or t in home_targets() or re.fullmatch(r"/+\*?", t) is not None


def tokenize(cmd):
    """Split into words, SEP for each unquoted separator char. ValueError on unclosed quote."""
    tokens, word, in_word, quote, i = [], [], False, None, 0

    def flush():
        nonlocal word, in_word
        if in_word:
            tokens.append("".join(word))
        word, in_word = [], False

    while i < len(cmd):
        c = cmd[i]
        if quote == "'":
            if c == "'":
                quote = None
            else:
                word.append(c)
        elif quote == '"':
            if c == '"':
                quote = None
            elif c == "\\" and i + 1 < len(cmd) and cmd[i + 1] in '"\\$`':
                i += 1
                word.append(cmd[i])
            else:
                word.append(c)
        elif c in "'\"":
            quote, in_word = c, True
        elif c == "\\":
            if i + 1 >= len(cmd):
                raise ValueError("trailing backslash")
            i += 1
            word.append(cmd[i])
            in_word = True
        elif c == "#" and not in_word:
            while i + 1 < len(cmd) and cmd[i + 1] != "\n":
                i += 1
        elif c in PUNCT:
            flush()
            tokens.append(SEP)
        elif c in " \t\r":
            flush()
        else:
            word.append(c)
            in_word = True
        i += 1
    if quote:
        raise ValueError("unclosed quote")
    flush()
    return tokens


def skip_opts(tokens, arg_opts):
    while tokens and tokens[0].startswith("-") and tokens[0] != "-":
        if tokens[0] == "--":
            return tokens[1:]
        tokens = tokens[2:] if tokens[0] in arg_opts else tokens[1:]
    return tokens


def strip_prefixes(tokens):
    while tokens:
        if ENV_ASSIGN.match(tokens[0]):
            tokens = tokens[1:]
            continue
        name = os.path.basename(tokens[0])
        if name == "sudo":
            tokens = skip_opts(tokens[1:], SUDO_ARG_OPTS)
        elif name == "env":
            tokens = skip_opts(tokens[1:], ENV_ARG_OPTS)
        elif name in KEYWORDS or name == "nohup":
            tokens = tokens[1:]
        elif name == "time":
            tokens = skip_opts(tokens[1:], ())
        elif name == "nice":
            tokens = skip_opts(tokens[1:], NICE_ARG_OPTS)
        elif name == "timeout":
            tokens = skip_opts(tokens[1:], TIMEOUT_ARG_OPTS)[1:]  # then the duration
        else:
            break
    return tokens


def git_subcommand(args):
    i = 0
    while i < len(args):
        if args[i] in GIT_ARG_OPTS:
            i += 2
        elif args[i].startswith("-"):
            i += 1
        else:
            return args[i], args[i + 1:]
    return None, []


def pull_rebases(args):
    return any(a == "--rebase" or (a.startswith("--rebase=") and a[9:].lower() not in ("false", "no"))
               or PULL_R.match(a) for a in args)


def push_forces(args):
    for a in args:
        if a == "--force" or a.startswith("--force-with-lease") or a == "--force-if-includes":
            return True
        if SHORT_F.match(a) or (not a.startswith("-") and a.startswith("+")):
            return True
    return False


def rm_hits(args):
    recursive, targets, after_dd = False, [], False
    for a in args:
        if after_dd or not a.startswith("-"):
            targets.append(a)
        elif a == "--":
            after_dd = True
        elif a == "--recursive":
            recursive = True
        elif not a.startswith("--") and ("r" in a or "R" in a):
            recursive = True
    return recursive and any(is_danger_target(t) for t in targets)


def check_segment(tokens, depth):
    tokens = strip_prefixes(tokens)
    if not tokens:
        return None
    name, args = os.path.basename(tokens[0]), tokens[1:]
    if name == "git":
        sub, rest = git_subcommand(args)
        if sub == "rebase":
            return "rebase"
        if sub == "pull" and pull_rebases(rest):
            return "pull-rebase"
        if sub == "push" and push_forces(rest):
            return "force-push"
    elif name == "rm":
        if rm_hits(args):
            return "rm-recursive"
    elif name in ("bash", "sh", "zsh"):
        for i, a in enumerate(args):
            if SHELL_C.match(a) and i + 1 < len(args):
                return check(args[i + 1], depth + 1)
    return None


def scan_raw(cmd):
    """Regex fallback for strings shlex cannot parse or nested deeper than MAX_DEPTH."""
    # the two option alternatives are disjoint (-C/-c vs any other option): no exponential backtracking
    git = r"""(?:^|[\s"'])git["']?(?:\s+["']?-[Cc]["']?\s+\S+|\s+(?!["']?-[Cc]["']?(?:\s|$))["']?-{1,2}\w[\w-]*(?:=[^\s"']*)?["']?)*"""
    end = r"""(?=["'\s]|$)"""
    targets = "|".join(re.escape(t) for t in RM_FIXED + home_targets())
    rules = (
        ("rebase", re.compile(git + r"""\s+["']?rebase\b""")),
        ("pull-rebase", re.compile(git + r"""\s+["']?pull\b.*?\s["']?(?:--rebase\b(?!=(?:[Ff][Aa][Ll][Ss][Ee]|[Nn][Oo])(?:["'\s]|$))|-[qvnpafdtk46]*r[qvnpafdtk46]*""" + end + ")")),
        ("force-push", re.compile(git + r"""\s+["']?push\b.*?\s["']?(?:--force\b|-[A-Za-z0-9]*f[A-Za-z0-9]*""" + end + r"""|\+\S)""")),
    )
    rm_cmd = re.compile(r"""(?:^|[\s"'])rm["']?\s(.*)""", re.S)
    rm_flag = re.compile(r"""(?:^|\s)["']?(?:--recursive|-[A-Za-z]*[rR][A-Za-z]*)""" + end)
    rm_target = re.compile(r"""(?:^|\s)["']?(?:/+\*?|""" + targets + r""")["']?(?=\s|$)""")
    cmd = re.sub(r"(?m)(?:^|(?<=\s))#.*$", "", cmd)
    for piece in re.split(r"[;&|\n()]+", cmd):
        for family, rx in rules:
            if rx.search(piece):
                return family
        m = rm_cmd.search(piece)
        if m and rm_flag.search(m.group(1)) and rm_target.search(m.group(1)):
            return "rm-recursive"
    return None


def split_heredocs(cmd):
    """Return (cmd without heredoc bodies, bodies fed to a shell). A heredoc with no closing line is left alone."""
    lines, out, shell_bodies, i = cmd.split("\n"), [], [], 0
    while i < len(lines):
        line = lines[i]
        out.append(line)
        i += 1
        for m in HEREDOC.finditer(line):
            if m.start() > 0 and line[m.start() - 1] == "<":
                continue  # here-string <<<
            word = m.group(2) or m.group(3) or m.group(4)
            for j in range(i, len(lines)):
                if (lines[j].lstrip("\t") if m.group(1) else lines[j]) == word:
                    before = line[:m.start()]
                    if (SHELL_BEFORE.search(before) or SHELL_C_BEFORE.search(before)
                            or PIPE_TO_SHELL.search(line[m.end():])):
                        shell_bodies.append("\n".join(lines[i:j]))
                    i = j + 1
                    break
    return "\n".join(out), shell_bodies


def check(cmd, depth=0):
    cleaned, shell_bodies = split_heredocs(cmd)
    family = check_text(cleaned, depth)
    for body in shell_bodies:
        family = family or check(body, depth + 1)
    return family


def check_text(cmd, depth):
    if depth > MAX_DEPTH:
        return scan_raw(cmd)
    try:
        tokens = tokenize(cmd)
    except ValueError:
        return scan_raw(cmd)
    segment = []
    for tok in tokens + [SEP]:
        if tok is SEP:
            family = check_segment(segment, depth) if segment else None
            if family:
                return family
            segment = []
        else:
            segment.append(tok)
    return None


def switch_value(path, key):
    """'on'/'off' from the last valid `ordo <key>: on|off` line of the file, else None (also on any read error)."""
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)  # O_NONBLOCK: a FIFO does not hang the open
        try:
            if not stat.S_ISREG(os.fstat(fd).st_mode):  # FIFO, device (/dev/zero), directory: silent
                return None
            with os.fdopen(fd, "rb", closefd=False) as f:
                data = f.read(MAX_SWITCH_FILE + 1)
        finally:
            os.close(fd)
        if len(data) > MAX_SWITCH_FILE:
            return None
        text = data.decode("utf-8-sig")  # utf-8-sig drops a leading BOM
    except (OSError, UnicodeDecodeError):
        return None
    value = None
    for line in text.split("\n"):
        line = line.strip()
        for v in ("on", "off"):
            if line == "ordo %s: %s" % (key, v):
                value = v
    return value


def guard_is_off(cwd):
    """True when the winning `ordo guard_hook:` line says off. Never raises: any problem leaves the guard on."""
    try:
        home = os.environ.get("HOME", "")
        paths = []
        if isinstance(cwd, str) and os.path.isabs(cwd):
            paths.append(os.path.join(cwd, "CLAUDE.md"))
        if home:
            paths.append(os.path.join(home, ".claude", "CLAUDE.md"))
        for path in paths:
            value = switch_value(path, "guard_hook")
            if value:
                return value == "off"
    except Exception:
        pass
    return False


def main():
    try:
        data = json.loads(sys.stdin.read())
        if not isinstance(data, dict):
            raise ValueError("payload is not a JSON object")
        if data.get("tool_name") != "Bash":
            return
        tool_input = data.get("tool_input")
        cmd = tool_input.get("command") if isinstance(tool_input, dict) else None
        if not isinstance(cmd, str):
            return
        family = check(cmd)
        if family and not guard_is_off(data.get("cwd")):
            reason = (
                "Blocked by ordo guard_bash rule %s: this command family is hard-denied. "
                "Run it yourself in this session with `! %s` if you really mean it." % (family, cmd)
            )
            print(json.dumps({"hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": reason,
            }}))
    except Exception as exc:  # fail open: a guard bug must never block Bash
        print("guard_bash: failed open (%s: %s)" % (type(exc).__name__, exc), file=sys.stderr)


if __name__ == "__main__":
    main()
    sys.exit(0)
