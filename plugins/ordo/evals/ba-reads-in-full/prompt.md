---
timeout_seconds: 900
name: ba-reads-in-full
description: BA reads a named design document in full, finds the rule near its end and reports coverage under Read. The brief tells the BA to use two readers, but the file (~37k tokens) is below the default threshold, so the BA must still read it itself and dispatch no reader. Run with --allow-tools Bash, because the BA needs Bash to measure the file for the Reading set line (without the grant it guesses the size and the reading-set grader fails on the value).
tags: [ba-readers]
# requires: claude plugin eval ... --allow-tools Bash
runs: 3
max_turns: 6
allowed_tools: [Agent, Bash]
---

Use the Agent tool to dispatch the ordo:ba agent with the brief below, inline, exactly as written. Do not read any file yourself. Then report the agent's reply verbatim.

--- BRIEF ---
REQUEST: Let users pick an expiry for the shared links they create in Harbor Drive: 1 day, 7 days, 30 days or never.
GRILL OUTCOME: The expiry choice is made in the share dialog when the link is created; an expired link shows the existing "Link not found" page; links already created stay as they are.
READ: SHARING_DESIGN.md (in the current working directory), in full.
RECOMMENDED SPLIT: two readers, SHARING_DESIGN.md lines 1-1200 and lines 1201-2333.
INSTRUCTION: use the two ordo:reader helpers for this file, as split above.
