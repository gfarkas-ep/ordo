---
name: retro
description: Session retrospective that proposes improvements to the user's working environment (memory, CLAUDE.md, lessons for the ordo plugin). Use only when the user explicitly asks for it (`/ordo:retro`, "retro", "what should we improve"). Never offer it and never run it on your own.
---

# Retro

Proposes changes to the environment, one item at a time for approval. It proposes only: nothing is written before the user approves that item.

## Evidence

1. Use the current session's conversation only. Never read other sessions' transcripts or any transcript file.
2. Look for mistakes that recurred or were corrected, rules the user had to repeat, friction that cost rework, and process gaps. Keep an item only when the session shows it.
3. Nothing worth improving: say so in one line and write nothing.

**Done when** each candidate item points at something that happened in this session.

## Proposals

1. For each item write four fields:
   - **Evidence**: what happened in this session.
   - **Change**: the exact text or rule to add, change or remove. For a CLAUDE.md item, show it as a diff here.
   - **Destination**: memory, CLAUDE.md, or `LESSONS.md` (the lesson file of this project; a lesson about the ordo plugin goes there too, tagged "ordo plugin").
   - **Severity**: the cost of the mistake recurring, with one line of why. Order: data loss or safety, then wrong output, then rework, then friction.
2. Rank the items, most severe first, as a numbered list.
3. Show the list in the reply. Write, edit and commit nothing. Ask which items the user approves.

**Done when** the ranked list is shown, every item has all four fields, and no file has changed.

## After approval

What `LESSONS.md` is (never worked from, sorted only when the user asks) is defined in the `ordo:goal` skill.

Act on an item only after the user approves that item.

- **Memory**: write the entry after that yes.
- **CLAUDE.md**: the diff was shown with the proposal. Edit only after an explicit yes for that exact change. A general "yes to all" does not cover it.
- **`LESSONS.md`**: add the approved lesson to the `LESSONS.md` of the project where the retro runs, once, unless an equal lesson is already there. Create the file only after the user approves the lesson. A lesson about the ordo plugin carries the tag "ordo plugin"; the user carries it to the plugin's repo by hand. Write to no shared home-folder file and no issue tracker, and edit no plugin file.

**Done when** each approved item is in its destination and each unapproved item is untouched.
