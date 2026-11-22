---
timeout_seconds: 1200
name: ba-claude-md-threshold
description: "AC9 level 2: the brief sets no settings; the project CLAUDE.md in the scaffold holds a low ordo reader_threshold_tokens (5000), the reading set (~12k tokens) is above it but far below the 200000 default, and the brief tells the BA to use readers whenever its rules permit. Only the CLAUDE.md value permits it, so the BA must dispatch ordo:reader and report split. Run with --scaffold and --allow-tools Bash (the BA measures the set with it). Level 3 (global ~/.claude/CLAUDE.md) is covered by ba-global-claude-md."
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
INSTRUCTION: dispatch ordo:reader helpers for this reading set whenever your rules for this run permit it; read it yourself when they do not. Name each reader's report path in the current working directory, as ./reader-<group>.md.
