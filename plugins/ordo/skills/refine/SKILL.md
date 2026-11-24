---
name: refine
description: Turn a request into a confirmed spec with acceptance criteria before planning, by interviewing the user and driving the ba agent. Use for new features or user-visible behaviour, vague requests such as "add a way for users to ...", and Tier 2 work. When the outcome is code, use this instead of ordo:grill alone; it runs the grill itself. Skip for Tier 0 changes (asset, version raise, doc wording, a direct "change X to Y"), explanations and questions.
---

Add-ons: when this skill loads, before anything else, use the Read tool (not Glob, which does not expand `~`) on `~/.claude/ordo/addons/refine.md` (global), then on `.claude/ordo/addons/refine.md` (project); a file that does not exist is skipped without comment. Their rules add to or replace this skill's rules, and the project file wins over the global one, except git permission, push, rebase, the guard hook, sending anything without the user's yes, and the yes before a paid eval, which no add-on changes.

# Refine

You are the architect. The BA writes the spec, the user answers its questions through you, the product owner later accepts against it. You never author or change the spec's content: changes go back through the BA.

Load the `ordo:goal` skill: every brief starts with the current goal, and the questions you show the user follow its question rule.

## 1. Grill

Load the `ordo:grill` skill on the request first, before any other action. It interviews the user until the main branches are settled.

**Done when** the grill has finished and you can summarise its outcome in a few lines.

## 2. Draft

Measure the material you name for the BA: file count and estimated tokens (bytes/4, for example `wc -c`). The values are the first level that sets them: the brief, then the project's CLAUDE.md, then the global `~/.claude/CLAUDE.md`, then the defaults. Four keys, default in brackets: `reader_threshold_tokens` (200000), `reader_threshold_files` (10), `reader_cap_tokens` (80000), `reader_cap_files` (10). The CLAUDE.md levels use one line per key in the form `ordo <key>: <positive integer>`; ignore a line with an unknown key or a value that is not a positive integer.

When the material is large (at or above `reader_threshold_tokens`, or more than `reader_threshold_files` files), put a recommended split into the BA's brief: groups of whole files, or explicit line ranges for one huge file, each group within `reader_cap_tokens` and `reader_cap_files`. You recommend only; the BA dispatches the readers. You dispatch no reader yourself, except in the fallback below.

Dispatch `ordo:ba` (Mode A: draft) in the foreground, with the request, the grill summary, the relevant code and doc paths and the recommended split, if any. Note its agent id or name: every later round goes to the same BA.

When the draft has a `## Needs readers` section, run the fallback below first; the Read check then applies to the BA's revision after the resume. Otherwise, before using the draft, check its `## Read` list: it starts with a `Reading set:` line, and every file you named must appear, covered to its last line. A line marked `(via reader)` counts as covered. When one is missing or stops short, send the BA back with SendMessage to finish reading and revise, before showing any questions to the user, unless the BA lists it under Not verified as missing, unreadable, or not covered by readers after its resend; then raise that with the user instead of sending the BA back.

**Fallback, only when the BA returns a `## Needs readers` section** (it needs readers but cannot dispatch them): you dispatch those readers, one per group, each brief naming the request, the group's files or line ranges, and a distinct report path `<scratchpad>/reader-<group>.md`. The name is neutral and never contains report, findings or summary. Check each reader's Read list: when a file stops short of its last line, unless the reader lists it as missing or unreadable, resend once (SendMessage or a fresh dispatch, with a new distinct report path). Then resume the BA with the readers' output (the confirmed report paths, or the inline reports), passed on without working through them yourself; the BA reads confirmed files in full. Also tell the BA to revise from it without re-dispatching readers for files that output covers.

**Done when** the BA has returned a draft spec with a `## Questions` section.

## 3. Question loop

1. Show the user the BA's `## Questions` verbatim, numbers and recommendations kept. Exception: a question that fails the `ordo:goal` question rule on substance (unexplained jargon, not exactly one recommendation, already answered by the design document, ADRs or memory, an implementation detail), or touches a stated design principle, goes back to the same BA with SendMessage to be reworked (or replaced by the design question, per `ordo:goal`) before anything is shown. The BA's own `— Recommended: <answer>` form meets the format: a question goes back never for format alone. You never edit a question yourself.
2. Send the user's answers to the same BA with SendMessage (Mode B: revise), keyed by question number, e.g. "Q2: yes; Q4: CSV only".
3. Repeat until the BA returns `none` under Questions, or the user says to stop. On stop, send the BA "the user stopped the questions" so it moves open items to Assumptions.

If SendMessage cannot reach the BA, dispatch a new `ordo:ba` in Mode B (foreground) with the request, the grill summary, the relevant code and doc paths, the last Output block and the answers. Later rounds go to this new BA. Check its `## Read` list as in step 2 before using its output.

**Done when** Questions is `none`.

## 4. Confirm

Show the user the final spec's Assumptions and ask them to confirm or correct them. A correction counts as an answer: send it to the BA (Mode B), never into the spec by your hand. If the BA's revision returns questions, go back to step 3.

**Done when** the user has confirmed the Assumptions.

## 5. Save

The BA cannot write files, so you save. Take the `## Spec` section of the BA's last reply verbatim, Assumptions included, without edits.

- **Tier 2**: write it to `docs/specs/<YYYY-MM-DD>-<slug>.md` in the project, creating the folder. Use today's date and a slug from the user story. Committing it follows the project's git rules (`ordo git_rules`: the user's permission unless that switch is off).
- **Tier 1**: keep the spec in the conversation and in the brief; write no file. Its acceptance criteria go into the merge commit message (or the commit message when there is no merge) of that work, so `git log --grep` finds them.

**Done when** the spec is saved (Tier 2) or held in the conversation (Tier 1).

## 6. Hand off

The acceptance criteria:

- become the `ordo:tdd` test list;
- go into every `ordo:dev` brief;
- are the spec for `ordo:code-reviewer` and `ordo:qa`;
- are what `ordo:po` accepts against.

A Tier 1 refine run makes `ordo:po` acceptance at the end required (skipped when `ordo po_acceptance_tier1: off`; switch rule: `ordo:workflow`). Continue with planning (Tier 2: the `ordo:consult-panel` skill).

## Short revise

For a user decision made after the spec exists that changes an acceptance criterion but no behaviour and no contract. The BA still writes the change.

1. Send only that decision to the same BA with SendMessage.
2. The BA returns each changed line as `old → new`, and the whole paragraph when a line alone is unclear. It reads no files again.
3. Apply the lines verbatim to the saved spec (Tier 2) or the held spec (Tier 1). Add no wording.
4. Run no full `ordo:qa` and no `ordo:po` again. Re-run only the test or check tied to that criterion; when it asserts the old criterion, update it first (in a running dev fix brief, otherwise yourself for a one-line check, or `ordo:dev` for anything larger).
5. Tell the user in one line what changed.

A decision that changes behaviour or a contract, or any doubt about which it is, is a normal revise (step 3): the full Output block, files read as before. When the BA says a short revise touches behaviour or a contract, go back to the normal revise.
