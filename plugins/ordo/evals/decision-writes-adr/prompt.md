---
name: decision-writes-adr
description: "Base ordo:decision behaviour: the user settles a design question and asks to record it, giving the facts. The ordo:decision skill must load, an ADR must be written with the Write tool to docs/decisions/YYYY-MM-DD-<slug>.md, and the file must carry the template headings (Context, Decision, Options considered, Consequences) and a Status line (Accepted). Run with --scaffold and --allow-tools Write."
tags: [reader-write]
# requires: claude plugin eval ... --scaffold --allow-tools Write
runs: 3
max_turns: 8
allowed_tools: [Skill, Read, Glob, Grep, Write]
---

Record this decision: the notes app stores each note as a markdown file on disk, not in SQLite. I settled it today.

Facts, use only these:
- The app is local and for one person. Notes must open in any editor and survive a file-sync tool.
- SQLite was the alternative. I rejected it because a binary database file cannot be diffed or merged by the sync tool.
- Easier with files: backups, diffs, editing outside the app. Harder: full-text search and updating several notes together.
- Revisit when the app becomes multi-user or holds more than 10,000 notes.
