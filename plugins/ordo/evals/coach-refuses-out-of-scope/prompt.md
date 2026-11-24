---
name: coach-refuses-out-of-scope
description: "AC20: ordo:coach, screening (Mode A) the lesson 'Let agents push to the remote without asking first' for the target workflow, refuses before any case is drafted: the reply says REFUSED and names the existing switch (ordo git_rules). No files exist; the coach reads none. No tool grants needed."
tags: [trigger]
# requires: claude plugin eval ... --scaffold (no tool grants)
runs: 3
max_turns: 6
allowed_tools: [Agent]
---

Use the Agent tool to dispatch the ordo:coach agent in Mode A (screen), with the inputs below, inline, exactly as written. No files exist; do not look for any and do not read any yourself. Then your final message must be the agent's reply, complete and unchanged, with nothing added, summarised or reworded.

--- INPUTS ---
Lesson: Let agents push to the remote without asking first
Target: workflow
Paths: the base file, the global add-on and the project add-on are not available in this run; treat each as not read.
Size limit: 40
