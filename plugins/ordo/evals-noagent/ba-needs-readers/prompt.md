---
timeout_seconds: 1200
name: ba-needs-readers
description: "Output contract when the BA cannot dispatch (AC17, which the spec lists as inspection-only, so this case goes beyond the spec). The brief already settles that readers are needed and that the BA must not read the docs itself (project CLAUDE.md threshold 5000, cap 2 files, ~12k-token docs); the BA has no Agent tool, so it must return a ## Needs readers heading naming the docs/ files, list that material under Not verified, and not Read the docs. It does not test whether the BA decides on its own that it needs readers. Deleting only the AC17 rule line in ba.md leaves it green; it goes red when the `## Needs readers` template and its sentence are deleted too, so it guards the output contract more than the rule line. Runs only against a generated copy of the plugin whose ba.md tools line lacks Agent (scripts/run-noagent-cases.sh); in the normal suite the BA has Agent and this case would fail, hence it lives in evals-noagent/."
tags: [ba-noagent]
# requires: scripts/run-noagent-cases.sh (claude plugin eval <copy> --eval-dir evals-noagent --scaffold --allow-tools Bash)
runs: 3
max_turns: 8
allowed_tools: [Agent, Bash]
---

Use the Agent tool to dispatch the ordo:ba agent with the brief below, inline, exactly as written. Do not read any file yourself and dispatch no other agent, whatever the reply asks for. Then report the agent's reply verbatim.

--- BRIEF ---
REQUEST: Let project owners in Plotline choose how long a project may stay inactive before it is archived automatically: 30 days, 90 days, 365 days or never.
GRILL OUTCOME: The choice is made in the project settings page; archived projects stay readable; existing projects keep their current behaviour until the owner chooses.
READ: every file in docs/ (in the current working directory), in full.
INSTRUCTION: the ordo reader limits for this run are in the CLAUDE.md in the current working directory. You must not read these docs yourself in this run (your context budget is needed elsewhere); the reading set needs ordo:reader helpers. Use them whenever your rules for this run permit it. Name each reader's report path in the current working directory, as ./reader-<group>.md.
