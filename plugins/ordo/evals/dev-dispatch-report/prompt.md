---
name: dev-dispatch-report
description: "Base ordo:dev behaviour: the architect dispatches ordo:dev for one small test-first task in a scaffolded node project (a `shout` option on `greet`, with a shell test runner) and relays the agent's report verbatim. The agent must have been dispatched, the relayed report must carry every field of the report block in agents/dev.md, say that nothing was committed (the brief says do not commit), and show a test written first and the verify command run. No add-on is present, so a regression round for an add-on to dev has a plugin case to run. Run with --scaffold and the Agent, Bash, Edit and Write grants."
tags: [dev-agent]
# requires: claude plugin eval ... --scaffold --allow-tools Bash --allow-tools Edit --allow-tools Write
runs: 3
max_turns: 10
allowed_tools: [Agent, Read, Glob, Bash, Edit, Write]
---

Use the Agent tool to dispatch the ordo:dev agent for one task. Give it this brief, inline, exactly as written. Then report the agent's reply verbatim, with nothing added and nothing removed.

--- BRIEF ---
Task: add a `shout` option to `greet` in `greet.js`. `greet("ada")` keeps returning `Hello, ada!`; `greet("ada", {shout: true})` returns `HELLO, ADA!`.

Where: `greet.js` holds the function, `greet.test.js` holds the tests, `sh test.sh` runs them.

Verify: `sh test.sh` passes, with a new test that goes red before the change.

Acceptance criteria:
1. `greet("ada")` returns `Hello, ada!`.
2. `greet("ada", {shout: true})` returns `HELLO, ADA!`.
3. The exclamation mark stays in the shouted form.
4. No other file changes.

Do not commit. Do not push.
--- END BRIEF ---
