---
name: consult-panel-seats
description: "Base ordo:consult-panel behaviour: the user asks for a consult on a small plan in a scaffolded node project that has a spec and a ROADMAP.md. The skill must load, the plan must be written to docs/plans/<YYYY-MM-DD>-<slug>.md, the three seats ordo:dev, ordo:qa and ordo:po must be dispatched, and the synthesis must carry the headings the skill states (Plan, Panel agrees on, Panel disagrees on, Changes I made to the plan, Open decisions for you). The user's approval comes after the synthesis, so the case needs none to pass. Run with --scaffold and the Bash, Edit and Write grants (batch dev-agent)."
tags: [dev-agent]
# requires: claude plugin eval ... --scaffold --allow-tools Bash --allow-tools Edit --allow-tools Write
runs: 3
max_turns: 24
allowed_tools: [Skill, Agent, Read, Glob, Grep, Write, Edit]
---

Run a consult on this plan before any code is written. Use the spec in `docs/specs/2026-11-23-report-json-flag.md`.

Goal: add a `--json` flag to `report.js` (the current goal in `ROADMAP.md`).

Plan sketch: parse `process.argv` in `report.js`; with `--json` print `JSON.stringify(rows)`, with no flag keep the text report, with any other flag print one line to stderr and exit 2. Tests go in `report.test.js`, run by `sh test.sh`.

I will approve or change the plan after you show me the panel's synthesis. Do not wait for my approval before showing it, and write no code.
