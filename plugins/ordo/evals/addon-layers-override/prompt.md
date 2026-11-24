---
name: addon-layers-override
description: "AC2, AC3: a global add-on for tdd has two rules (end with LAYER-GLOBAL-27; start with LAYER-GLOBAL-KEEP-27) and the project add-on conflicts with the first (end with LAYER-PROJECT-27 instead) and with a base rule of tdd (refactoring belongs to review, after the loop; the project replaces it: the loop is Red, Green, REFACTOR-27, Repeat). The project layer wins on both conflicts, and the global rule it does not contradict stays: the reply starts with LAYER-GLOBAL-KEEP-27 (proves the global file was read), ends with LAYER-PROJECT-27 and not LAYER-GLOBAL-27, names REFACTOR-27 after green and does not say refactoring belongs to review. The scaffold writes the global layer into the run's own HOME and refuses when HOME is the real home. Run with --scaffold (no tool grants)."
tags: [trigger]
# requires: claude plugin eval ... --scaffold (no tool grants)
runs: 3
max_turns: 8
allowed_tools: [Skill, Read, Glob, Grep]
---

Load the ordo:tdd skill with the Skill tool, then summarise in three or four sentences what a seam is, where its tests live, and what the steps of the red-green loop are.
