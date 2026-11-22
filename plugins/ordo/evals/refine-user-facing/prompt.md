---
name: refine-user-facing
description: User-facing Tier 1 change runs the refine skill
tags: [trigger]
runs: 3
max_turns: 8
allowed_tools: [Skill, Read, Glob, Grep]
append_system_prompt: |
  A SessionStart hook printed:
  ordo: load the ordo:workflow skill before your next reply (tiers, agents, skills).
---

Change the wording and layout of the signup error messages.
