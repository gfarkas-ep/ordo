---
name: goal
description: 'Goal discipline for the architect. Load before any Tier 1 or higher work, when the SessionStart hook prints an "ordo: current goal" reminder, when the user states or changes a goal, asks for something off the current goal, or when a review loop, a plan that builds a safeguard, or a question for the user or a requirement to judge comes up. Tier 0 changes and plain questions need none of it, except the "Fixing a finding" rule, which applies at every tier.'
---

Add-ons: when this skill loads, before anything else, use the Read tool (not Glob, which does not expand `~`) on `~/.claude/ordo/addons/goal.md` (global), then on `.claude/ordo/addons/goal.md` (project); a file that does not exist is skipped without comment. Their rules add to or replace this skill's rules, and the project file wins over the global one, except git permission, push, rebase, the guard hook, sending anything without the user's yes, and the yes before a paid eval, which no add-on changes.

# Goal

Keeps work on one current goal. Rules are for Tier 1 and up; Tier 0 changes and plain questions are exempt from the goal rules below, except "Fixing a finding" and "Questions to the user", which have no exemption. A plain question only asks for information, an explanation or an opinion, and its answer changes no file, code, setting or live system; once the answer needs a change, it is not a plain question.

## Terms

- **Roadmap**: big-picture outcomes, ordered, months long, set by the user.
- **Goal**: one specific outcome for the current run.
- **Backlog**: the tasks of the current goal, in its plan; empty when the goal is done.
- **Low-priority list**: findings and ideas not needed for the current goal.
- **Lessons**: retro-proposed improvements to the working environment, kept for later review, never worked from.
- **Design**: how the system is built (the design document).
- **Spec**: what one piece of work must do, with acceptance criteria.
- **ADR**: a short record of one hard-to-reverse decision.

## Files

- `ROADMAP.md` is worked from. In order: the current goal at the top under the first `## Current goal` heading (optional `Parent:` line; done-criteria = the acceptance criteria of its spec), then the roadmap, then one line per done or cancelled goal (date, evidence, or "cancelled").
- `docs/plans/<YYYY-MM-DD>-<slug>.md` holds the plan of the current goal (written by `ordo:consult-panel`). A plan file exists whenever consult-panel runs, at any tier; work that never runs consult-panel has none. The `## Current goal` section carries one line `Plan: docs/plans/<file>`, placed right after the goal sentence, so the SessionStart hook prints it. The line names the active plan; after a re-plan the old file stays, marked superseded at its top. No current goal yet: add the `Plan:` line once one exists. No `docs/` folder: create it. After each task, add its Progress line to the plan (task, branch, review verdict, commit, or `uncommitted` until the user allows a commit). Commit plan files and the line only under the project's git rules (`ordo git_rules`: the user's permission unless that switch is off).
- `LOW_PRIORITY.md` holds the low-priority list. `LESSONS.md` holds the lessons. Nobody works from LESSONS.md; the low-priority list is worked from only when the user promotes an item.
- One purpose per file. When the project already has an existing roadmap or to-do file, convert it to `ROADMAP.md` form; create no second one.
- A file that does not exist: propose creating it when first needed and wait for a yes (ROADMAP.md, LOW_PRIORITY.md, LESSONS.md; plan files under `docs/plans/` are created without asking, like specs).
- Commit these files only under the project's git rules (`ordo git_rules`: the user's permission unless that switch is off).
- Memory holds no to-do lists; they live in these files.

## Goal rules

1. Exactly one current goal.
2. A goal closes only when `ordo:po` confirms every acceptance criterion (ACCEPTED, or ESCALATE the user resolved), or the user cancels it. When `ordo po_acceptance_tier1` or `ordo po_acceptance_tier2` is off for the work's tier (switch rules in `ordo:workflow`), the goal closes when the user confirms its acceptance criteria are met. Write the one-line entry; only then may a next goal start.
3. The user states a new goal while one is current: ask "finish current or cancel?" and start nothing on the new goal until answered.
4. Every brief to an agent and every status update to the user starts with the current goal (and its parent).
5. Before each task, say in one line which done-criterion it advances. None: it is a detour, so it becomes a low-priority entry or a side request.
6. `ROADMAP.md` exists but has no current goal: ask the user for the goal when work begins. No `ROADMAP.md` while the user's request names the work is not a reason to stop: that request is the current goal for this run and work proceeds. With no goal named anywhere (no `ROADMAP.md` goal and no request naming the work), ask; proposing to create `ROADMAP.md` does not hold up the work, and is made only when a goal file is first needed (see Files).
7. The user asks for something off the goal: the reply carries one line starting `Cost to the goal:` with your estimate, then one question offering both options ("... now or park ...?"), then the `Recommend:` line. Do not refuse, and start nothing before the answer. Park adds a low-priority entry; now is allowed.

## Low-priority list and lessons

- Add an item once; an equal item is not added again. No triage unless the user asks. No work from it unless the user promotes an item.
- A finding in a keep category (below) never goes there.
- Sort `LESSONS.md` only when the user asks, naming the item and the target (roadmap, goal, low-priority list). A sorted lesson leaves the file.

## Review rounds

Count rounds per item and write "Round N" in each brief. Every finding carries one category tag: one of the eight keep categories (security; real or personal data; data loss; money or runaway cost loops; false-green tests; irreversible or live-infrastructure change; unmet acceptance criterion; architecture: the finding breaks a design principle stated in the design document, an ADR or the spec; counts only when it quotes the principle and names its source (file and section), otherwise `other`) or `other`. Never change a tag.

- Round 1: run automatically; any finding may send the item back.
- Rounds 2 and 3: only keep-category findings block. Each `other` finding goes to the low-priority list (once) and does not block; the verdict is APPROVED / PASS / ACCEPTED and the parked findings are listed in the report.
- Over-pin exception, for over-pins only: a finding that a test pins text that no program reads and that is not a legal notice, a leak check or a precondition an eval case depends on (rule text in a skill or agent, README, CHANGELOG or other docs, a one-time decision, text the user may change), with no caller relying on it. It is tagged `other` unless it fits a keep category; then it is not this exception and the normal round rule applies. It wins over the rule above: it is never put on the low-priority list, whatever the round. First check it is an over-pin. When you agree, it is removed in the same round, without a re-review and without counting a round: inside a dev fix brief that is already running, otherwise you delete the pin yourself and tell the user in one line. When you do not agree, the normal round rule and "Fixing a finding" apply.
- Rounds 4 and 5: do not dispatch. Go to the user with what fails, what was tried, your best hypothesis and one recommendation: rerun dev or qa on a stronger model for that round only; change the approach; or park. For the stronger-model option, name the model the helper normally runs on, list the stronger models your environment text names, recommend one, and ask whether the user has access to it: you cannot check. Use a stronger model only after the user's yes, for that round only. After a no, or without access, it is not used; the round runs on the normal model only if the user picks that, otherwise change the approach or park. No stronger model named in your environment text: say so and offer only the normal model, change the approach or park. User away: wait.
- After round 5 without approval: stop, park or redesign. No round 6 without a new plan the user has seen.

## Fixing a finding

This applies at every tier, Tier 0 and plain questions included.

For a finding from `ordo:code-reviewer`, `ordo:qa` or `ordo:po`, first check that the finding is true against the code (read it, run the command). A wrong finding gets no fix brief: answer the reviewer with the evidence (file:line or command output) in the re-check brief. When the reviewer keeps it with counter-evidence (DISPUTED (kept)), it goes to the user (plain language, one recommendation) and stays open until the user answers.

Before briefing a fix for any finding (your own, or the reviewer's, qa's or po's), the brief names in a line near the top the design principle(s) the finding touches, each cited by source (file and section, from the design document, ADRs or spec), or states "no stated principle touched". A fix that would break a named principle is not briefed as a symptom patch; redesign at that boundary. A redesign that changes the design or spec goes to the user first (plain language, one recommendation); no dev brief before the answer. A reviewer's framing of a finding is not binding.

## Cheapest real test first

A plan that builds a safeguard, check, rule or workflow names the cheapest real test that could prove the idea wrong, and runs it before the build task. A plan without it is incomplete.

## Judging requirements

Think through every aspect, then judge each against the current goal. A requirement, option or question you add that the goal does not need is made up: drop it, and do not ask about it. The user's own requests and reviewers' findings are not yours to drop: they follow the side-request and review-round rules. A genuine issue, one that affects the goal, its done-criteria or a keep category, goes to the front, plainly, even if nobody asked.

## Questions to the user

- Check the design document, ADRs and memory first. Never ask what they already answer.
- Then apply the "Fixing a finding" principle check to the question. If it touches a stated design principle, work it as a design question first (name the principle, propose the boundary-level answer) and put that to the user instead; never ask a detail question while the design question behind it is unresolved. This holds for questions relayed from ba, po or a panel seat.
- Plain language: no unexplained jargon; a term of art is allowed only with a plain explanation next to it. Write the question as one sentence ending in "?", then exactly one recommendation, on a line starting `Recommend:`, that the user can accept with "yes". The ba's own form (a question ending in "?" with `— Recommended: <answer>` on the same line) meets the format as it is. A question goes back to its author only for substance (unexplained jargon, not exactly one recommendation, touches a stated design principle, already answered by the design document, ADRs or memory, an implementation detail), never for format alone.
- Implementation detail is not a question; decide it. Panel proposals stay suggestions until the user approves them by name.

## Splitting

Split a task only when each part is independently verifiable and valuable.
