---
name: tier0-asset-no-review
description: "Worth-it AC4: adding an existing asset to the README is Tier 0, done directly: no code review, no refine, no new test file. The README is edited. Run with --scaffold --allow-tools Edit."
tags: [worth-it]
# requires: claude plugin eval ... --scaffold --allow-tools Edit
runs: 3
max_turns: 10
allowed_tools: [Skill, Agent, Read, Edit, Write, Glob, Grep]
append_system_prompt: |
  A SessionStart hook printed:
  ordo: load the ordo:workflow skill before your next reply (tiers, agents, skills).
---

Add the image logo.png, which is already in this folder, to the top of README.md.
