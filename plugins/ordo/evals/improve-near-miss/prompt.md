---
name: improve-near-miss
description: "AC14 negative control: a request to improve a function in the user's own code (not ordo) is ordinary coding work. ordo:improve must not run, ordo:coach must not be dispatched, and the reply must not offer ordo:improve; the function is read and the reply engages with it. Run with --scaffold (no tool grants)."
tags: [trigger]
# requires: claude plugin eval ... --scaffold (no tool grants)
runs: 3
max_turns: 8
allowed_tools: [Skill, Agent, Read, Glob, Grep]
---

Can you improve the parse_price function in acme.py? I would like it to be better quality.
