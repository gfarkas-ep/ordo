---
timeout_seconds: 1200
name: ba-brief-beats-claude-md
description: "Regression guard for AC9 per-key precedence, not red-capable: with the precedence sentence deleted from ba.md it failed 0 of 6 runs; on the current ba.md it passed 10 of 12. A stronger per-key sentence (tried as 0.6.2, reverted) passed 11 of 12, no measurable gain. The scenario: the project CLAUDE.md in the scaffold holds reader_threshold_tokens 5000, reader_cap_tokens 20000 and reader_cap_files 1; the brief sets only `ordo reader_cap_files: 5`. The brief wins reader_cap_files and CLAUDE.md supplies the threshold and token cap, so the 5-file, ~12k-token set is above the threshold and fits one reader: the BA must dispatch exactly one ordo:reader and report split. A BA that ignores CLAUDE.md reads it itself (no dispatch); one that lets CLAUDE.md win the file cap dispatches five. Run with --scaffold and --allow-tools Bash (the BA measures the set with it)."
tags: [ba-readers]
# requires: claude plugin eval ... --scaffold --allow-tools Bash
runs: 3
max_turns: 8
allowed_tools: [Agent, Bash]
---

Use the Agent tool to dispatch the ordo:ba agent with the brief below, inline, exactly as written. Do not read any file yourself. Then report the agent's reply verbatim.

--- BRIEF ---
REQUEST: Let project owners in Plotline choose how long a project may stay inactive before it is archived automatically: 30 days, 90 days, 365 days or never.
GRILL OUTCOME: The choice is made in the project settings page; archived projects stay readable; existing projects keep their current behaviour until the owner chooses.
READ: every file in docs/ (in the current working directory), in full.
SETTINGS FOR THIS RUN: ordo reader_cap_files: 5.
INSTRUCTION: dispatch ordo:reader helpers for this reading set whenever your rules for this run permit it, using as few readers as the caps allow; read it yourself when the rules do not permit it. Name each reader's report path in the current working directory, as ./reader-<group>.md.
