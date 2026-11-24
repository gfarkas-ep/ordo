---
name: improve
description: Turns one lesson into a checked eval case and a local add-on change to an ordo skill or agent, applied only after the user's pick; also shows the effective stack of a skill or agent, the add-on history, restores an earlier version and offers a contributor PR. Use only when the user explicitly asks for it (`/ordo:improve`, "improve ordo", "turn this lesson into an add-on", "show the effective stack", "restore the add-on"). Never offer it and never run it on your own.
---

# Improve

One lesson per run becomes one eval case and one add-on change: a plain markdown file of bullet rules named after a skill or agent (`<name>.md`), kept in `~/.claude/ordo/addons/` (global) or `.claude/ordo/addons/` (project). Base skills and agents are never edited. This skill reads no add-on itself.

The helper `improve-eval.sh` sits in this skill's base directory; run it as `sh <base directory of this skill>/improve-eval.sh <subcommand>`. Below it is written `improve-eval.sh <subcommand>`. It writes every add-on and history file; this skill never writes those by hand. This skill writes only the case folder and the candidate files, under `<root>/ordo/improve/`.

## Start

1. Never offer it, never suggest it and never start it on your own. Start only when the user asks for it in this conversation. A request for a retro alone is not a request for this skill.
2. Take the lesson from the first source that applies:
   - the request describes the behaviour to change: use that description as the lesson and ask nothing about where it comes from;
   - an `ordo:retro` ran in this conversation: offer that retro's ordo lessons first;
   - otherwise ask the user to choose one of three: describe the behaviour; run `ordo:retro` on this session now (retro sees only the current session); or pick a saved "ordo plugin" lesson from the `LESSONS.md` of the project, each with its date (an entry with no date is shown without one).
3. When `ordo:retro` runs or proposes a lesson here, the user approves it as `ordo:retro` requires before it counts as the lesson.
4. One lesson per run. A second lesson is a new run.

**Done when** one lesson is fixed in one or two sentences and nothing has been written.

## Screen

Dispatch `ordo:coach` in Mode A before any case is drafted. Give it the inputs its file lists for Mode A: the lesson; the target, the name of the skill or agent the lesson is about (ask once when unclear); the paths of the base file of the target (`../<name>/SKILL.md` or `../../agents/<name>.md` from this skill's base directory) and of the global and project add-on files `~/.claude/ordo/addons/<name>.md` and `.claude/ordo/addons/<name>.md` (either may be missing).

Show the verdict, with its `Not read:` line.

- ACCEPTED: take its `Target:` as the target.
- REFUSED: show its reason and its `Switch:` line.
- COVERED: show its `Covered by:` line.

On REFUSED or COVERED report it and stop before any case or paid run. The user may restate the lesson as a new run.

**Done when** the verdict is shown, and after REFUSED or COVERED nothing is written and nothing has run.

## Case

1. Find the root: run `improve-eval.sh scope`. It prints `scope:` and, for `global` and `project`, `root:`. For `ask`, ask the user once per run which folder (`~/.claude` or the project's `.claude`) and use only that one; with no answer write nothing. Use the same root for the whole run.
2. Draft the lesson's eval case in `<root>/ordo/improve/evals/<slug>/` (a short lowercase slug of the lesson): `prompt.md` (front matter and the prompt, the form of the plugin's own cases in its `evals/` folder), `graders/` (one grader file per check, each failing when the lesson's behaviour is missing), and a `scaffold.sh` when the sandbox needs files, with a `case.yaml` naming it as the plugin's cases do. The draft names the tool grants the case needs (Bash, Edit or Write; none when it needs none). Grader types: regex, tool_used, tool_order, file_exists, llm. Regexes are JavaScript: make one case-insensitive with a `flags: i` line, never an inline `(?i)` (the helper refuses it). The case's wall-time estimate comes from the plugin's `evals/results/` for plugin cases and from earlier runs of the case under `<root>/ordo/improve/runs/`; write "guess" only when neither exists. The case must fail on the stack without the lesson's rule; a case that cannot fail checks nothing.
3. Show the case in full: the prompt, every grader, the scaffold script.
4. Use the case only after the user's yes. Edit it and show it again on a change request; the old yes does not carry over. After the yes the case is never changed, by this skill or by the coach.

**Done when** the case is shown in full and either the user said yes or the run stopped.

## Plan

Load `ordo:eval-plan` and write the plan before any eval runs. It lists:

- every stage: the red check; the lesson round (each candidate, 3 runs); the regression round, with its case names;
- N candidates (default 2, at most 3);
- the regression cases, named for the user to check: the cases of earlier accepted lessons (the folders in `<root>/ordo/improve/evals/` that hold an `accepted` file) and the plugin's own cases in its `evals/` folder for the same skill or agent the add-on changes (a case counts when its prompt or graders exercise that skill or agent; no case tags exist, so the user checks the list);
- expected pass rate, budget and stop rule, as `ordo:eval-plan` requires.

The plan is one loop budget for the whole run. Inside it, only a fix outside the case (arguments, `--out`, environment) reruns without asking again; report once at the end. Any change to a case file stops the run, shows the case again and needs a new yes. After the plan's yes, a changed case also needs an amended plan (saved, shown, covering the added runs) with a yes, before the next paid stage. One yes to the saved plan covers all its stages; more candidates, more runs or a higher budget need a new plan and a new yes.

Start no `claude plugin eval` command before the user's explicit yes in their own message. `improve-eval.sh run` starts one. A yes given before the plan is shown (for example "yes, run the red check" while the case is approved) does not count: show the saved plan and wait for a yes to it.

When the user declines the eval, no stage runs, `ordo:coach` is still dispatched in Mode B, and the table shows no results (Stages step 2 is free); see Choose and write.

**Done when** the plan is shown with all its parts and no eval has run.

## Stages

After the yes, run the stages in order. Each stage is one or more `improve-eval.sh run` calls. Its arguments: `--name <target>`, `--case <lesson case folder>`, `--runs <k>`, `--out <a new folder under <root>/ordo/improve/>`, and the layers under test as `--global <file>` and `--project <file>` (only files that exist). Pass absolute paths with no `.` or `..` part; the helper refuses others, and refuses an `--out` outside `<root>/ordo/improve/`. Every `run` call gets its own new `--out` folder (for example `<root>/ordo/improve/runs/<stage>-<candidate>-<try>/`); a folder that holds a results JSON is refused. The red and lesson calls pass the grants the case names: pass them with `--allow-tools <Tool>`, once per tool. It prints the path of the results JSON, then one line per failing grader per run, `fail <case> run <i> <grader>: <explanation>`; read these lines and the pass count of each case (`passed` for each run, under `.cases[].arms.with[]`) before judging a stage. Exit 3 means the stage is void: a grader threw (for example an invalid regex) and `error: grader <grader> threw in case <case>: <explanation>` is on stderr. Fix the grader as a case change (see Plan), and never count it as a fail. A case below full pass makes the eval itself exit 1; that is a result, not an error.

1. **Red check**: `improve-eval.sh run --stage red` on the current stack (the global and project add-on files of the target as they are, each only when it exists), 3 runs. The red check counts as red only when the failing graders are the ones that test the lesson itself. When any of the 3 runs passes, stop: the case does not capture the issue, and no candidate is written. When only setup or side graders fail (the lesson behaviour already happened), stop the same way, before candidates. Show the user the `fail` lines and recommend a reshaped case (a new case needs a new yes, and an amended plan).
2. **Candidates**: run `improve-eval.sh limit` and warn when the current add-on has more lines than that limit (the next candidate consolidates it). Dispatch `ordo:coach` in Mode B with the lesson, the target, the paths of the base file and the current add-on files, the scope folder `<root>/ordo/addons/` (the root of the Case section), the limit, N and the path of the approved case. Write each candidate it returns to `<root>/ordo/improve/candidates/`, one file each (`<name>-<k>.md`). The coach writes nothing. A candidate over the limit is not run (count its lines with `awk 'END { print NR }' <file>`).
3. **Lesson round**: `improve-eval.sh run --stage lesson --runs 3` with the candidate in place of the add-on file of the scope layer and the other layer as it is: each candidate runs the lesson case 3 times, in parallel (one call per candidate, started together). A candidate below 3/3 is dropped and reported with its score.
4. **Regression round**: `improve-eval.sh run --stage regression`, with no `--case` (the lesson case does not run again), each earlier case as `--earlier <folder>` (only case folders that hold an `accepted` file; its grants are in that file) and each plugin case as `--plugin-case <name>`, the cases named in the plan. A plugin case that needs a tool grant takes `--allow-tools <Tool>` for each tool, repeated as needed; the grants per case are in the helper's header and its refusal message names the grants a case needs. The helper refuses one regression call that mixes cases with different grants, so make one call per grant and join the results. Only a candidate at 3/3 runs the regression round. The cases are the earlier lessons and the plugin's cases for the target, not the whole plugin suite. With no earlier case and no plugin case, skip the regression round and say so. When every candidate is below 3/3, there is no regression round and no change; the user may drop the lesson or start a new plan.

Abort on the stop rule of the plan. A run aborted by it still gets the after-run comparison in the next section.

**Done when** every candidate has its lesson score, every 3/3 candidate has its regression result or the skip note, and no add-on has been written.

## Choose and write

1. Show a table, one row per candidate: candidate, lesson result, regressions, the coach's `Change:` line, its `Consolidated:` line, and the diff against the current add-on file (or "no previous add-on"). Then show `ordo:eval-plan`'s after-run comparison of actual against plan.
2. The user can pick one candidate, reject all, or drop the lesson. The add-on changes only after a pick. Reject all and drop the lesson write nothing.
3. Write the pick only through `improve-eval.sh write` with `--root <root> --name <target> --from <candidate file> --lesson "<the lesson>" --result "<the eval result, for example lesson 3/3, regression 6/6>"`. The helper saves the previous add-on to `<root>/ordo/addons/history/` first, then writes the file, and refuses a file over the limit. Write no add-on or history file any other way, and nothing in the plugin cache, the plugin's `evals/` folder or a base skill or agent file.
4. When the user declined the eval and accepts a candidate anyway, write it with `--result "not verified"`.
5. After a successful write, put a file `accepted` (the date, the history file name and the case's tool grants) in that lesson's case folder; it is a marker, not part of the case. Dropped, rejected or red-stopped lessons get none. The regression round of later runs uses only case folders with that file.

**Done when** the table and the comparison are shown and the add-on file is unchanged or written by the helper after a pick.

## Stack, history and restore

Each of these starts only when the user asks for it. None needs a lesson, a case or an eval plan.

1. **Effective stack** of a skill or agent: Read its base file and the add-on files `~/.claude/ordo/addons/<name>.md` and `.claude/ordo/addons/<name>.md` (a missing file counts as empty). List the rules in short, each with its layer (base, global, project), in that order. Later layers win on a conflict: mark a rule overridden by a later layer, and name the layer that overrides it. A rule no later layer touches stays. When an add-on file has more lines than the limit (`improve-eval.sh limit`), warn that the next candidate will consolidate it.
2. **History**: `improve-eval.sh history --root <root> --name <name>` prints one line per saved version, newest first: the file name, the lesson and the eval result. Show each as "the version replaced by <lesson> (<result>)" with its file name, and the current add-on file separately, as the current version. `<root>` is `~/.claude` (global) or the project's `.claude`; when both could apply, ask which.
3. **Restore**: only after the user names the version, run `improve-eval.sh restore --root <root> --name <name> --version <file name>`. Read the entry's `previous:` line before the yes. The helper saves the file it replaces to history first. An entry whose `previous:` line says none records "no previous add-on": restoring it removes the add-on, after the helper saved the file to history; warn the user of that before the yes. After a restore, name the accepted lesson cases whose rule the restored version no longer holds; the next plan lists them for the user to keep or drop. Show the history list again afterwards.

**Done when** the stack or the list is shown, or the named version is restored by the helper.

## Share

After a pick, offer a contributor PR only for a change that was verified, never for one written as "not verified". The PR carries the base edit the lesson implies (a change to the skill or agent file itself, not the add-on), the eval case and the results. The base edit is shown only as a diff in the draft, or made in a clone of the plugin repo that the user names, never in the installed plugin or `~/.claude/plugins/cache/`. It is drafted as `CONTRIBUTING.md` asks (small, test-first, all test scripts passing, the case planned with `ordo:eval-plan`).

Draft nothing for sending before the user's yes to the offer. Show the draft in full, and send nothing without a further yes to that exact text.

**Done when** no offer was made for a "not verified" change, and nothing is drafted or sent without the user's yes.

## Out of scope

An add-on never changes these, so this skill never writes one for them and never helps around them:

- git permission, push and rebase
- the guard hook
- sending anything without the user's yes
- the yes before a paid eval

A lesson that targets one of them ends in the screen. The coach names the switch where one exists (`ordo git_rules`, `ordo guard_hook`). This skill also never edits a base skill or agent, a copy or fork of one, or the plugin's `evals/` folder, and never writes a case or candidate outside `<root>/ordo/improve/`.
