---
name: grill-asks-one-round
description: "Base ordo:grill behaviour: the user asks to be grilled on a small design idea (a daily digest email for a team issue tracker). The ordo:grill skill must load; the reply must ask one numbered round of questions in the skill's format (`❓ **Q1** — ...` each followed by a `➡️` recommended answer) and wait: no second round, no answers assumed. Run with --scaffold (batch trigger, no tool grants)."
tags: [trigger]
runs: 3
max_turns: 8
allowed_tools: [Skill, Read, Glob, Grep]
---

Grill me on this idea: a daily digest email for our team's issue tracker (see README.md). It would list what changed yesterday. I have not decided who gets it, when it goes out, or what it contains.
