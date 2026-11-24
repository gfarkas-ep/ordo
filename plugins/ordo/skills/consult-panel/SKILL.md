---
name: consult-panel
description: Architect + dev + qa + po review of a plan before any code. Use for Tier 2 work (hard to reverse, auth/security, real data, contract or schema change, or several modules) and whenever the user asks for a consult.
---

Add-ons: when this skill loads, before anything else, use the Read tool (not Glob, which does not expand `~`) on `~/.claude/ordo/addons/consult-panel.md` (global), then on `.claude/ordo/addons/consult-panel.md` (project); a file that does not exist is skipped without comment. Their rules add to or replace this skill's rules, and the project file wins over the global one, except git permission, push, rebase, the guard hook, sending anything without the user's yes, and the yes before a paid eval, which no add-on changes.

# Consult panel

You are the architect. The panel stress-tests your plan before code exists; the user approves the result.

Load the `ordo:goal` skill: every brief starts with the current goal.

## 1. Write the plan

Save it in the project as `docs/plans/<YYYY-MM-DD>-<slug>.md` (today's date, slug from the goal). Create `docs/plans/` (and `docs/`) when missing. Never overwrite silently: when that file already exists (same day, same slug), pick a new slug or ask. The file survives a reboot and a compaction. A plan file exists whenever this skill runs, at any tier; work that never runs consult-panel has none. A consult without a spec still saves the plan.

The plan holds:

- **Goal** and success criteria.
- **Current goal**: the goal this plan serves (and its parent, if any), as in `ROADMAP.md`.
- **Cheapest real test**: the cheapest test that could prove the idea wrong. A plan that builds a safeguard, check, rule or workflow runs it before any build task; without it the plan is incomplete.
- **Requirements**: point to the spec from the `ordo:refine` skill (Tier 2: `docs/specs/<date>-<slug>.md`); do not restate them. Add the non-functional requirements (scale, latency, cost, data safety) the spec does not cover, where they matter.
- **Approach** and the alternatives you rejected, with why.
- **Tasks**: each with what, where (files) and verify (test or command).
- **Test seams**: each with what it catches and what it misses.
- **Risks** and what to revisit as the system grows.
- **Assumptions** you are making.
- **Progress**: an empty section when the file is first written. After each task (dev done, review verdict in) add one line with exactly four items: task, branch, review verdict, commit; the verdict reads "review off" when that tier's code review switch is off (`ordo code_review_tier1` or `ordo code_review_tier2`).

**Done when** every task has all three of what/where/verify.

Then set the `Plan: docs/plans/<file>` line in the `## Current goal` section of `ROADMAP.md`, right after the goal sentence (the `ordo:goal` skill holds the rule). Commit these files only under the project's git rules (`ordo git_rules`: the user's permission unless that switch is off), same rule as `docs/specs/`: list the plan file and the `ROADMAP.md` change as ready to commit.

Re-plan: write a new plan file, point `Plan:` at it, keep the old file and mark it superseded in a line at its top.

## 2. Convene the panel

Skipped when `ordo plan_review: off` (switch rule: `ordo:workflow`): dispatch no dev, qa or po seat; the plan file is still written and saved and the user's approval is still required. The dev seat follows `plan_review` alone, never `ordo dev_helper_tier2`.

Dispatch all three in parallel, in the foreground. Point them at the plan file path in `docs/plans/`, the spec and the relevant code; keep the prompts short. With no spec (a consult the user asked for without refine), skip the po seat and say so under Open decisions.

Every seat prompt also carries the question rule: a question for the user is plain language, one sentence ending in "?", then one `Recommend:` line the user can accept with "yes"; check the design document, ADRs and memory first; implementation detail is not a question.

- `ordo:dev`: "Review this plan as the implementer. Edit nothing. Report: tasks that are unclear or mis-sized, files or callers the plan missed, a simpler approach if one exists, and your estimate of the riskiest task. Under 400 words."
- `ordo:qa`: "Review this plan as QA. Edit nothing. Report: whether the seams can catch the risks listed, missing failure cases, behaviours with no planned test, and how each task's verify step could pass while the behaviour is wrong. Under 400 words."
- `ordo:po` (Mode A): "Review this plan against the spec. Edit nothing. Report: value and scope, proposed cuts, spec gaps, and escalations. Under 400 words."

## 3. Synthesise

Skipped when `ordo plan_review: off`: show the user the plan's goal, its task list and the plan file path, then go to step 4.

Present to the user:

```
## Plan — <one line>
## Panel agrees on        — ...
## Panel disagrees on     — point — dev says — qa says — po says — my recommendation
## Changes I made to the plan — ...
## Open decisions for you — numbered, each with my recommendation; po escalations go here
```

Keep each panelist's points attributed; resolve disagreements with a recommendation rather than averaging them.

## 4. Wait and record

Wait for the user's explicit approval. Then write every decision the user made into the same plan file, under a section titled "Changes after the panel". For each hard-to-reverse decision among them, also load the `ordo:decision` skill and record it as an ADR: both, not either. Only then start the first task.

The user rejects or parks the plan: remove the `Plan:` line from `ROADMAP.md` and mark the plan file "not approved" at its top; keep the file.

End of step 4: list as ready to commit the plan file, the `ROADMAP.md` change and any ADRs; commit only under the project's git rules (`ordo git_rules`: the user's permission unless that switch is off).
