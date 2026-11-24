---
name: grill
description: Interview the user relentlessly about a plan, decision or idea until every branch is settled.
---

Add-ons: when this skill loads, before anything else, use the Read tool (not Glob, which does not expand `~`) on `~/.claude/ordo/addons/grill.md` (global), then on `.claude/ordo/addons/grill.md` (project); a file that does not exist is skipped without comment. Their rules add to or replace this skill's rules, and the project file wins over the global one, except git permission, push, rebase, the guard hook, sending anything without the user's yes, and the yes before a paid eval, which no add-on changes.

# Grill

Adapted from mattpocock/skills `grilling` (MIT, see LICENSE).

Interview the user until you reach a shared understanding. Map the topic as a **design tree**: every decision branches into the decisions that hang off it.

Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are already settled: the questions you can ask now without guessing at answers you have not heard. Ask the whole frontier in one round, numbered, each with your recommended answer. Then wait.

```
❓ **Q1** — **<title>**: <the question, with the options>

➡️ <your recommended answer>
```

Word each question so "yes" accepts your recommendation.

Each answer reshapes the tree: settled decisions push the frontier outward. Recompute it and ask the next round. A question that depends on another question still open in this round belongs to a later round.

Finding **facts** is your job. When a question needs a fact from the code, files or tools, send a subagent to find it and ask the rest of the frontier meanwhile; only the questions downstream of that fact wait. The **decisions** are the user's: put each one to them.

The session is done when the frontier is empty: every branch visited, nothing silently assumed. Summarise the settled decisions and wait for the user to confirm before acting on them.
