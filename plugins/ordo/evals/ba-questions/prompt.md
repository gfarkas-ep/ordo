---
timeout_seconds: 600
name: ba-questions
description: Vague request yields numbered questions with recommended answers and Given/When/Then criteria
tags: [ba]
runs: 3
max_turns: 6
allowed_tools: [Agent]
---

Use the Agent tool to dispatch the ordo:ba agent with the request below, inline, exactly as written. No files exist; do not look for any. Then report the agent's reply verbatim.

--- REQUEST ---
Make the app faster and nicer for our customers.
