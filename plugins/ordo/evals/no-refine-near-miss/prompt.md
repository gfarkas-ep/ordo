---
name: no-refine-near-miss
description: Explanation request does not run the refine skill
tags: [trigger]
runs: 3
max_turns: 8
allowed_tools: [Skill, Read, Glob, Grep]
append_system_prompt: |
  A SessionStart hook printed:
  ordo: load the ordo:workflow skill before your next reply (tiers, agents, skills).
---

Explain how a data export feature usually works.
