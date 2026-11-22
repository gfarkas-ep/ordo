---
timeout_seconds: 1200
name: ba-uses-readers
description: BA measures a reading set above a low threshold given in the brief, dispatches ordo:reader per group, marks reader-covered files (via reader) and carries the deciding rule into the spec. Run with --allow-tools Bash, because the BA needs Bash to measure the set (without the grant it guesses the size and the measured grader fails). Write is not granted, so readers return the inline report, which AC18 accepts.
tags: [ba-readers]
# requires: claude plugin eval ... --allow-tools Bash
runs: 3
max_turns: 8
allowed_tools: [Agent, Bash]
---

Use the Agent tool to dispatch the ordo:ba agent with the brief below, inline, exactly as written. Do not read any file yourself. Then report the agent's reply verbatim.

--- BRIEF ---
REQUEST: Let project owners in Plotline choose how long a project may stay inactive before it is archived automatically: 30 days, 90 days, 365 days or never.
GRILL OUTCOME: The choice is made in the project settings page; archived projects stay readable; existing projects keep their current behaviour until the owner chooses.
READ: every file in docs/ (in the current working directory), in full.
SETTINGS FOR THIS RUN: ordo reader_threshold_tokens: 10000. ordo reader_cap_tokens: 5000. ordo reader_cap_files: 2.
INSTRUCTION: use ordo:reader helpers for this reading set. Name each reader's report path in the current working directory, as ./reader-<group>.md.
