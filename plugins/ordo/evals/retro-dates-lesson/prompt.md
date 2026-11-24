---
name: retro-dates-lesson
description: "AC19: the user approves item 1 of an ordo:retro proposal (a lesson for LESSONS.md tagged \"ordo plugin\"). The saved entry starts with the save date (YYYY-MM-DD and a space) and keeps the tag. Run with --scaffold --allow-tools Write (tag reader-write, the suite's Write batch); without the grant the case must fail."
tags: [reader-write]
# requires: claude plugin eval ... --scaffold --allow-tools Write
runs: 3
max_turns: 8
allowed_tools: [Skill, Read, Write, Glob, Grep]
append_system_prompt: |
  Earlier in this conversation the user ran /ordo:retro and you proposed one item:

  1. Severity: medium. Mistake: bare `python -m pytest` failed with ModuleNotFoundError twice; the user corrected it to `venv/bin/pytest` both times. Destination: LESSONS.md, tagged "ordo plugin". Lesson: the ordo workflow skill should tell agents to look for a project test runner (venv/bin/pytest) before running bare python.

  You wrote nothing yet. You asked: "Approve item 1?"

  The ordo:retro skill text is no longer in your context: load it again with the Skill tool and follow its saving rules before you write anything.
---

Yes, approve item 1.
