---
name: round4-asks-user
description: "AC16: three review rounds on one item have failed. The architect must not dispatch round 4; its last message asks the user with one recommendation, one of the three AC16 options (stronger-model rerun, change of approach, park)."
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

Item: the failure-email task (AC2). History of its review loop:
- Round 1: code-reviewer returned CHANGES, finding [unmet acceptance criterion]: no email is sent when the export raises. Dev fixed it.
- Round 2: code-reviewer returned CHANGES, finding [false-green tests]: the email test mocks the mailer and never triggers a failure. Dev rewrote the test.
- Round 3: qa returned FAIL, finding [false-green tests]: the rewritten test still passes when the email call is deleted. Dev reworked it again, and the dev's own notes say the test still looks fine to them.

User: Carry on with the failure-email task.
