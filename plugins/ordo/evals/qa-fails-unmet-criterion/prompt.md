---
name: qa-fails-unmet-criterion
description: "Base ordo:qa behaviour: the architect dispatches ordo:qa on finished work in a scaffolded node project (a `slugify` function with a shell test runner and a short SPEC.md) where the tests pass but acceptance criterion AC3 of the spec is not met, and relays the agent's report verbatim. The agent must have been dispatched, the relayed report must give the verdict FAIL, name the unmet criterion (AC3: leading and trailing whitespace) with evidence, and carry the report headings of agents/qa.md. No add-on is present, so a regression round for an add-on to qa has a plugin case to run. Run with --scaffold and --allow-tools Bash."
tags: [bash-skills]
# requires: claude plugin eval ... --scaffold --allow-tools Bash
runs: 3
max_turns: 10
allowed_tools: [Agent, Read, Glob, Bash]
---

Use the Agent tool to dispatch the ordo:qa agent to verify finished work. Give it this brief, inline, exactly as written. Then report the agent's reply verbatim, with nothing added and nothing removed.

--- BRIEF ---
Task: verify the finished `slugify` function in `slug.js` against `SPEC.md` (acceptance criteria AC1 to AC3). The tests are in `slug.test.js`.

Where: the current directory. It is not a git repository, so there is no diff range; judge the files as they are.

Verification command: `sh test.sh`

Round 1. Edit nothing.
--- END BRIEF ---
