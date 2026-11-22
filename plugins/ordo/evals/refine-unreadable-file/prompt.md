---
timeout_seconds: 1200
name: refine-unreadable-file
description: "AC24 Read check: run through the ordo:refine skill with the grill already done, the request names docs/export-rules.md (exists) and docs/partner-terms.md (not in the fixture). The BA lists the missing file under Not verified; refine must not send it back for that file (no second ordo:ba dispatch, no SendMessage) and must raise the file with the user in its final message. Run with --scaffold; no Bash grant needed. The Needs-readers-first ordering is not covered (AC17 cannot be driven in the sandbox)."
tags: [refine-read]
# requires: claude plugin eval ... --scaffold
runs: 3
max_turns: 12
allowed_tools: [Skill, Agent, SendMessage, Read, Glob, Grep]
---

Use the ordo:refine skill for the request below. I already ran the grill myself and its outcome is below, so skip step 1 and do not ask me anything yet: go to step 2, dispatch ordo:ba with the brief, run the Read check on its draft as the skill says, and then continue as the skill says up to showing me what you need from me. Do not save any file. Follow the skill's steps and checks exactly as written, even where you expect a step to change nothing.

REQUEST: Let workspace admins export a workspace's data as CSV from the admin page, following the export rules and the partner terms.
GRILL OUTCOME: The export button sits on the admin page; only admins see it; the export follows the existing export rules; partner-specific limits come from the partner terms.
MATERIAL FOR THE BA: docs/export-rules.md and docs/partner-terms.md (both in the current working directory), each in full.
