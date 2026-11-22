---
timeout_seconds: 900
name: reader-extracts-file
description: reader writes its extract to the path in the brief, reads it back and replies with the path and the Read list. Run with --allow-tools Write (the grant is per invocation, a case cannot set it); without it this case must fail.
tags: [reader-write]
# requires: claude plugin eval ... --allow-tools Write
runs: 3
max_turns: 6
allowed_tools: [Agent]
---

Use the Agent tool to dispatch the ordo:reader agent with the brief below, inline, exactly as written. Do not read any file yourself. Then your final message must be the agent's reply, complete and unchanged, with nothing added, summarised or reworded.

--- BRIEF ---
REQUEST: Let users pick an expiry for the shared links they create in Harbor Drive: 1 day, 7 days, 30 days or never.
READ: SHARING_DESIGN.md (in the current working directory), every line.
OUTPUT PATH: ./reader-sharing.md (write your extract to this file, in the current working directory).
