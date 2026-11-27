---
name: domain-skill-plugin
description: "Item 15 probe: the user asks for one small JavaScript change through the ordo:dev agent and names no skill. A second, test-only plugin (acme, under this case folder, loaded through plugins:) offers a skill that fits the task. The architect must pick it itself and name it in the brief; the agent must load it with the Skill tool, follow it (a tag in the code comment) and put its skills line right after Not verified. The skill's rules and name appear nowhere in the prompt. Run with --scaffold and the Bash, Edit and Write grants."
tags: [dev-agent]
# requires: claude plugin eval ... --scaffold --allow-tools Bash --allow-tools Edit --allow-tools Write
runs: 3
max_turns: 12
allowed_tools: [Agent, Skill, Read, Glob, Bash, Edit, Write]
---

Use the ordo:dev agent to add a `shout` option to `greet` in `greet.js`. `greet("ada")` keeps returning `Hello, ada!`; `greet("ada", {shout: true})` returns `HELLO, ADA!`. `greet.test.js` holds the tests and `sh test.sh` runs them; the change needs a new test that goes red before the change. Do not commit. Report the agent's reply verbatim, with nothing added and nothing removed.
