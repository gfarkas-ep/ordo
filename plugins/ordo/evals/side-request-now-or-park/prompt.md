---
name: side-request-now-or-park
description: "AC6: the architect works on a current goal (ROADMAP.md shows it, a task is in progress). The user asks for an unrelated Tier 1 behaviour change. The architect must state the cost to the goal and ask \"now or park?\" in its last message, and must neither start the work (no Agent dispatch; Edit and Write are not granted) nor refuse before the answer."
tags: [trigger]
# requires: claude plugin eval ... (no scaffold_script, so no --scaffold; the suite runs it in its trigger batch; no tool grants beyond the listed ones; Agent dispatch is the guarded path, Edit and Write are not granted)
runs: 3
max_turns: 6
allowed_tools: [Skill, Read, Glob, Grep, Agent]
---

You are the architect in a Claude Code session with the ordo plugin installed. Here is the earlier part of this session, which is the only evidence available:

A SessionStart hook printed:
ordo: current goal (from ROADMAP.md). Load the ordo:goal skill before your next reply.
## Current goal
Nightly CSV export of invoices to the accounting system.
Done when: the export file has one row per invoice (AC1); a failed run sends an email (AC2); a rerun the same night does not duplicate rows (AC3).

User: Go on with the export.
Assistant: (Tier 1, advances AC1) Brief written for the dev: build the row writer. Dev is mid-task on `export/rows.py`; AC1 tests are red, the rest of the goal is untouched.

User: By the way, please add a `--since` date filter to the `report` command in the CLI and update its docs.
