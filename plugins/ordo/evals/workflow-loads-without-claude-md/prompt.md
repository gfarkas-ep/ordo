---
name: workflow-loads-without-claude-md
description: Plain behaviour-change request with no injected text and no CLAUDE.md loads the workflow skill and states a tier (real hook delivery)
tags: [trigger]
runs: 3
max_turns: 6
allowed_tools: [Skill, Read, Glob, Grep]
---

In this repo, add input validation to the signup form: reject emails without an @ and passwords under 8 characters.
