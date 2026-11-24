---
name: addon-rule-followed
description: "AC7, AC2: a project add-on (.claude/ordo/addons/tdd.md, placed by the scaffold) holds a rule only the add-on carries: end every reply with the line ADDON-PROJ-41. The user asks for ordo:tdd to be loaded and for a short summary; the reply must end with the marker, so the skill read the add-on and followed it over its base text. Run with --scaffold (no tool grants)."
tags: [trigger]
# requires: claude plugin eval ... --scaffold (no tool grants)
runs: 3
max_turns: 8
allowed_tools: [Skill, Read, Glob, Grep]
---

Load the ordo:tdd skill with the Skill tool, then summarise in two or three sentences what a seam is and where its tests live.
