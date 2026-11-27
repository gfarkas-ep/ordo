---
name: domain-skill-listed-missing
description: "AC9 of the domain skills spec: the project CLAUDE.md (written by the scaffold) has a line that lists a skill which is not installed; the only installed skill (test-only acme plugin) does not fit the task. The user asks for one small JavaScript change through the ordo:dev agent and names no skill. The agent must be dispatched, the final reply must name the listed skill as not installed (skipped) on one line, and the brief must not tell the agent to load it. Run with --scaffold and the Bash, Edit and Write grants."
tags: [dev-agent]
# requires: claude plugin eval ... --scaffold --allow-tools Bash --allow-tools Edit --allow-tools Write
runs: 3
max_turns: 12
allowed_tools: [Agent, Skill, Read, Glob, Bash, Edit, Write]
---

Use the ordo:dev agent to add a `shout` option to `greet` in `greet.js`. `greet("ada")` keeps returning `Hello, ada!`; `greet("ada", {shout: true})` returns `HELLO, ADA!`. `greet.test.js` holds the tests and `sh test.sh` runs them; the change needs a new test that goes red before the change. Do not commit. Finish with one message that holds everything I should know: any note you made before dispatching, then the agent's reply verbatim.
