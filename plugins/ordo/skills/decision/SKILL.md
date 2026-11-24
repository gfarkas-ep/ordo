---
name: decision
description: Records a hard-to-reverse decision as a short ADR in the project's docs/decisions/. Use after the user approves a Tier 2 plan, or when the user settles a design question worth remembering ("record this decision", "ADR").
---

Add-ons: when this skill loads, before anything else, use the Read tool (not Glob, which does not expand `~`) on `~/.claude/ordo/addons/decision.md` (global), then on `.claude/ordo/addons/decision.md` (project); a file that does not exist is skipped without comment. Their rules add to or replace this skill's rules, and the project file wins over the global one, except git permission, push, rebase, the guard hook, sending anything without the user's yes, and the yes before a paid eval, which no add-on changes.

# Decision record

An ADR records **why** something changed and what else was considered. The design document, where a project has one, holds the **current** design only. Keep history, incidents and rejected options in ADRs; keep the design document describing what is true now.

## Steps

1. **Check for an existing record.** `grep -ril "<topic>" docs/decisions/`. When the decision is already recorded, link to it; when this one replaces it, set the old one to `Superseded by <new file>`.
2. **Write the record** to `docs/decisions/YYYY-MM-DD-<slug>.md` (create the folder when missing), using the template below. Keep it under 40 lines. Use only facts from the approved plan and the conversation.
3. **Update the design document** when the project has one and the decision changes it: edit the affected section to describe the new current state, and add a one-line link to the ADR. When the project's rules require the user's consent to amend it, show the edit and wait.
4. **Report** the file path(s) created or changed.

## Template

```markdown
# <Decision as a short statement>

- **Date:** YYYY-MM-DD
- **Status:** Accepted | Superseded by <file>

## Context
<The situation and the forces at play. 2–5 lines.>

## Decision
<What we do now. 1–3 lines.>

## Options considered
- **<Chosen>** — why it won.
- **<Alternative>** — why not.

## Consequences
- Easier: ...
- Harder: ...
- Revisit when: ...
```
