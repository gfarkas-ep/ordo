---
timeout_seconds: 1200
name: ba-global-only-small
description: "AC9 level 3, lookup only: no project CLAUDE.md; the global CLAUDE.md in the run HOME holds reader_threshold_tokens 1000 and the reading set (2 files, ~2.6k tokens) is above it. Dispatching a reader is optional above the threshold, so the case does not grade it; it grades that the BA looked up the global ~/.claude/CLAUDE.md with Bash although the project has no CLAUDE.md and the brief names no settings. Run with --scaffold and --allow-tools Bash. The scaffold writes only under the run HOME and refuses to run on the real home."
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
READ: docs/plotline-boards.md and docs/plotline-billing.md (in the current working directory), in full; together about 10 KB.
INSTRUCTION: dispatch ordo:reader helpers for this reading set whenever your rules for this run permit it; read it yourself when they do not. Name each reader's report path in the current working directory, as ./reader-<group>.md.
