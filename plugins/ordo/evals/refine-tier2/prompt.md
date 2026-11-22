---
name: refine-tier2
description: Tier 2 request (schema change) runs the refine skill
tags: [trigger]
runs: 3
max_turns: 8
allowed_tools: [Skill, Read, Glob, Grep]
append_system_prompt: |
  A SessionStart hook printed:
  ordo: load the ordo:workflow skill before your next reply (tiers, agents, skills).
---

Change the database schema for user accounts: split the single "name" column into "first_name" and "last_name" and migrate the existing rows.
