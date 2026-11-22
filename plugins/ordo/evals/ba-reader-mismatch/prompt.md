---
timeout_seconds: 1200
name: ba-reader-mismatch
description: "BA holds a prior reader reply that covers docs/archive-policy.md but misquotes line 12 (45 days instead of the real 180). It must not re-dispatch a reader for that file (it must dispatch readers for the other material), must use the file's own text in the spec, and must note the mismatch under Not verified. Run with --allow-tools Bash, because the BA needs Bash to measure the set. Write is not granted."
tags: [ba-readers]
# requires: claude plugin eval ... --scaffold --allow-tools Bash
runs: 3
max_turns: 8
allowed_tools: [Agent, Bash]
---

Use the Agent tool to dispatch the ordo:ba agent with the brief below, inline, exactly as written. Do not read any file yourself. Then report the agent's reply verbatim.

--- BRIEF ---
REQUEST: Show project owners a notice on the archive page that states how many days an archived project stays readable before it is deleted.
GRILL OUTCOME: The notice sits at the top of the archive page and shows the period in days; it is shown for every archived project.
READ: every file in docs/ (in the current working directory), in full.
SETTINGS FOR THIS RUN: ordo reader_threshold_tokens: 10000. ordo reader_cap_tokens: 5000. ordo reader_cap_files: 2.
INSTRUCTION: use ordo:reader helpers for this set; reader extracts are what the spec should rest on. Nobody has checked the earlier reader reply against the files.
PRIOR READER REPLY (from an earlier round; it covers docs/archive-policy.md):
### docs/archive-policy.md
**rule**
- `docs/archive-policy.md:12` "Archived projects stay readable for 45 days after archiving, then they are deleted." — sets how long archived projects remain readable
## Read
- docs/archive-policy.md: lines 1-30 of 30
