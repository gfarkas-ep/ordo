---
timeout_seconds: 1200
name: ba-resends-short-read
description: "AC10 and AC16 together (does not isolate AC10: with only the AC10 bullet deleted the AC16 bullet still yields the same behaviour; red needs both deleted). The brief carries a prior reader reply whose Read list stops at line 30 of docs/archive-policy.md (40 lines in the fixture, the extension rule sits on line 39). The BA must make exactly one ordo:reader dispatch for the uncovered range only (from line 31, not a range starting at 1). no-whole-file catches a re-dispatch worded '1-40', '1 to the end' or 'whole file'; a whole-file brief worded only 'in full' is not caught (a correct range brief may say 'read lines 31-40 in full'). no-sendmessage is a guard only: the BA has no SendMessage tool. Run with --scaffold and --allow-tools Bash (the BA measures the set with it). Write is not granted, so the reader returns the inline report."
tags: [ba-readers]
# requires: claude plugin eval ... --scaffold --allow-tools Bash
runs: 3
max_turns: 8
allowed_tools: [Agent, Bash]
---

Use the Agent tool to dispatch the ordo:ba agent with the brief below, inline, exactly as written. Do not read any file yourself. Then report the agent's reply verbatim.

--- BRIEF ---
REQUEST: Show project owners a notice on the archive page that states how many days an archived project stays readable and whether they can extend it.
GRILL OUTCOME: The notice sits at the top of the archive page and shows the period in days; it is shown for every archived project.
READ: docs/archive-policy.md (in the current working directory), in full.
SETTINGS FOR THIS RUN: ordo reader_threshold_tokens: 500. ordo reader_cap_tokens: 5000. ordo reader_cap_files: 2.
INSTRUCTION: use ordo:reader helpers for this set. Name each reader's report path in the current working directory, as ./reader-<group>.md.
PRIOR READER REPLY (from an earlier round; it covers docs/archive-policy.md):
### docs/archive-policy.md
**rule**
- `docs/archive-policy.md:12` "Archived projects stay readable for 180 days after archiving, then they are deleted." — sets how long archived projects remain readable
## Read
- docs/archive-policy.md: lines 1-30 of 40
