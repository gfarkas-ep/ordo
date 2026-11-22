#!/usr/bin/env python3
"""SessionStart hook (ordo plugin): print the workflow line, then the `## Current goal` section of ROADMAP.md.

The workflow line (one line telling the session to load the ordo:workflow skill) is written
and flushed first, before ROADMAP.md is read, so no ROADMAP.md problem can suppress it.

Reads the hook JSON on stdin; the project dir is its "cwd" when that is a string,
else the process cwd. The goal is the first line equal to `## Current goal`
(CRLF normalised, trailing spaces ignored); its section runs to the next line
starting with `## ` or EOF, minus leading and trailing blank lines. Output is a
one-line header plus the section, capped at 15 lines and 1200 bytes (whole lines);
a cut ends with `…(truncated, see ROADMAP.md)`.

Prints only the workflow line when there is no ROADMAP.md, it is unreadable or not UTF-8,
there is no section or it is empty. Always exits 0, never writes to stderr.

Right after the workflow line (and before the goal block, even without a goal) it prints one
line `ordo: switched off: <key> (<where>), ...` naming each of the 12 switch keys that is off
at its winning level, in README order; <where> is `project CLAUDE.md` or `~/.claude/CLAUDE.md`.
The project dir's CLAUDE.md beats $HOME/.claude/CLAUDE.md; no value at either level means on.
The lines are read with switch_value() imported from guard_bash.py in this directory, so the
guard and the hook share one rule. The import and the read happen after the workflow line is
flushed and any failure prints no switch line. Nothing extra is printed when no key is off.

Standard library only; no file writes, no network, no subprocess.
"""
import json
import os
import sys

WORKFLOW_LINE = "ordo: load the ordo:workflow skill before your next reply (tiers, agents, skills)."
HEADER = "ordo: current goal (from ROADMAP.md). Load the ordo:goal skill before your next reply."
TRUNCATED = "…(truncated, see ROADMAP.md)"
SWITCH_KEYS = ("guard_hook", "git_rules", "eval_budget", "dev_helper_tier1", "dev_helper_tier2",
               "code_review_tier1", "code_review_tier2", "plan_review", "qa_check",
               "po_acceptance_tier1", "po_acceptance_tier2", "stall_watch")
MAX_LINES = 15
MAX_BYTES = 1200


def project_dir():
    try:
        data = json.loads(sys.stdin.read())
        if isinstance(data, dict) and isinstance(data.get("cwd"), str) and data["cwd"]:
            return data["cwd"]
    except Exception:
        pass
    return os.getcwd()


def goal_section(text):
    lines = text.replace("\r\n", "\n").split("\n")
    start = next((i for i, l in enumerate(lines) if l.rstrip(" ") == "## Current goal"), None)
    if start is None:
        return []
    section = []
    for line in lines[start + 1:]:
        if line.startswith("## "):
            break
        section.append(line)
    while section and not section[0].strip():
        section.pop(0)
    while section and not section[-1].strip():
        section.pop()
    return section


def switched_off_line(proj):
    """The `ordo: switched off: ...` line, or "" when no key is off or anything goes wrong."""
    try:
        sys.dont_write_bytecode = True  # importing guard_bash must not write a .pyc
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        from guard_bash import switch_value
        levels = [(os.path.join(proj, "CLAUDE.md"), "project CLAUDE.md")]
        home = os.environ.get("HOME", "")
        if home:
            levels.append((os.path.join(home, ".claude", "CLAUDE.md"), "~/.claude/CLAUDE.md"))
        off = []
        for key in SWITCH_KEYS:
            for path, where in levels:
                value = switch_value(path, key)
                if value:
                    if value == "off":
                        off.append("%s (%s)" % (key, where))
                    break
        return "ordo: switched off: " + ", ".join(off) if off else ""
    except Exception:
        return ""


def main():
    sys.stdout.write(WORKFLOW_LINE + "\n")
    sys.stdout.flush()
    proj = project_dir()
    line = switched_off_line(proj)
    if line:
        sys.stdout.write(line + "\n")
        sys.stdout.flush()
    with open(os.path.join(proj, "ROADMAP.md"), "rb") as f:
        text = f.read().decode("utf-8")
    section = goal_section(text)
    if not section:
        return
    kept, size = [], 0
    for line in section:
        size += len(line.encode("utf-8")) + 1
        if len(kept) >= MAX_LINES or size > MAX_BYTES:
            kept.append(TRUNCATED)
            break
        kept.append(line)
    sys.stdout.write("\n".join([HEADER] + kept) + "\n")


if __name__ == "__main__":
    try:
        main()
    except BaseException:  # fail open and silent: a goal hook bug must never disturb a session
        pass
    sys.exit(0)
