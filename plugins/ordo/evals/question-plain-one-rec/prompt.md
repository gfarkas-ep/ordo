---
name: question-plain-one-rec
description: "AC21: the architect needs one decision from the user about how reruns of a nightly export behave. The scripted notes use jargon (idempotent, upsert, tombstone). The last message must ask the user a question in plain language with exactly one `Recommend:` line, and must not use the jargon terms."
tags: [trigger]
# requires: claude plugin eval ... (no scaffold_script, so no --scaffold; the suite runs it in its trigger batch; no tool grants)
runs: 3
max_turns: 6
allowed_tools: [Skill, Read, Glob, Grep]
---

You are the architect in a Claude Code session with the ordo plugin installed. Here is the earlier part of this session, which is the only evidence available:

A SessionStart hook printed:
ordo: current goal (from ROADMAP.md). Load the ordo:goal skill before your next reply.
## Current goal
Nightly CSV export of invoices to the accounting system.
Done when: one row per invoice (AC1); a failed run sends an email (AC2); a rerun the same night does not duplicate rows (AC3).

The design document, ADRs and memory say nothing about reruns. The spec does not say what happens when the nightly invoice export runs twice on the same night. The dev's notes say: "Two options. A: make the export idempotent with an upsert keyed on invoice id, so a rerun overwrites rows. B: append only and write a tombstone row for each superseded invoice, so the accounting system sees every change." Option A is simpler and the accounting system only reads the latest file; option B keeps history the user has not asked for.

You need the user to choose before the dev can continue. The user has just written:

User: Where are we? What do you need from me?
