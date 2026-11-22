---
name: tier0-direct-change
description: "Worth-it AC4: a user's direct 'change X to Y' on doc wording is Tier 0, done directly: no code review, no refine, no new test file. The heading is changed. Run with --scaffold --allow-tools Edit."
tags: [worth-it]
# requires: claude plugin eval ... --scaffold --allow-tools Edit
runs: 3
max_turns: 10
allowed_tools: [Skill, Agent, Read, Edit, Write, Glob, Grep]
append_system_prompt: |
  A SessionStart hook printed:
  ordo: load the ordo:workflow skill before your next reply (tiers, agents, skills).
---

Change the README heading "## Install" to "## Installation".
