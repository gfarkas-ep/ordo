---
name: addon-none-silent
description: "AC1: with no add-on in the global or the project folder, a skill that carries the load line behaves as before and mentions no add-on. The user asks for ordo:tdd to be loaded and for a short summary; the reply must not mention add-ons. Run with --scaffold (no tool grants)."
tags: [trigger]
# requires: claude plugin eval ... --scaffold (no tool grants)
runs: 3
max_turns: 8
allowed_tools: [Skill, Read, Glob, Grep]
---

Load the ordo:tdd skill with the Skill tool, then summarise in two or three sentences what a seam is and where its tests live.
