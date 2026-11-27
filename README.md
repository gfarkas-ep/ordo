# ordo

ordo makes Claude Code work to a discipline: process sized by tier (a typo fix gets none, a risky change gets a spec, a reviewed plan and a review), review rounds that are capped and then go to you, one goal at a time, and rules that are backed by evals. Seven agents and twelve skills carry it out: the main session acts as the architect, who plans, sets test seams and delegates, and the role agents are the means.

| Name | Kind | Job |
|---|---|---|
| `ordo:dev` | agent (Sonnet) | Senior developer: implements one task test-first from a brief that names what, where and how it is verified |
| `ordo:qa` | agent (Sonnet) | Senior QA: checks that tests can catch a regression, runs the checks, returns PASS/FAIL |
| `ordo:code-reviewer` | agent (Opus, read-only) | Reviews a diff against spec and standards, returns APPROVED/CHANGES |
| `ordo:ba` | agent (Sonnet, read-only) | Writes the spec: user story, Given/When/Then criteria, edge cases, assumptions, open questions |
| `ordo:po` | agent (Opus, read-only) | Consult-panel seat on value and scope; accepts finished work against the spec: ACCEPTED/REJECTED/ESCALATE |
| `ordo:reader` | agent (Sonnet) | Reads a large set of files in full for the ba and writes verbatim extracts with `path:line`; fallback for large material only; the architect dispatches it only if the ba cannot |
| `ordo:coach` | agent (Opus, read-only) | Called only by `ordo:improve`: screens one lesson (refused, already covered or accepted) and drafts candidate add-on files; it writes nothing |
| `ordo:tdd` | skill | Test-first method: seams, red-green loop, test anti-patterns |
| `ordo:diagnose` | skill | Bug, failure or slowdown: reproduce, find the seam, fix test-first |
| `ordo:refine` | skill | Grill, then the ba question loop, until the spec has no open questions |
| `ordo:consult-panel` | skill | Plan review by dev, qa and po before Tier 2 work; the plan is saved at `docs/plans/<date>-<slug>.md` with a Progress section and the decisions taken after the panel |
| `ordo:decision` | skill | Records a decision as a short ADR in `docs/decisions/` |
| `ordo:grill` | skill | Interviews you until a plan has no open questions |
| `ordo:eval-plan` | skill | Plans and budgets a paid or long eval run before it starts, compares the result with the plan after |
| `ordo:goal` | skill | Goal discipline for the architect: one current goal, side-request rule, capped review rounds, plain questions with one recommendation |
| `ordo:workflow` | skill | The architect workflow (tiers, which agent or skill to use, git rules); the SessionStart hook line tells the main session to load it |
| `ordo:retro` | skill | End-of-session improvement proposals, only when you invoke it; nothing is written without your approval; approved lessons go to the project's `LESSONS.md` (tag "ordo plugin" for plugin lessons); each saved lesson starts with the date it was saved |
| `ordo:feedback` | skill | Drafts a feedback or issue report, prints it in full and sends it only after your explicit yes on that exact text; also shows or clears your usage log; only when you invoke it |
| `ordo:improve` | skill | Turns one lesson into a checked eval case and a local add-on change to an ordo skill or agent, applied only after your pick; also shows the effective stack, the add-on history, restores an earlier version and offers a contributor PR; only when you invoke it |

The tier workflow that ties them together is the `ordo:workflow` skill; the SessionStart hook tells the main session to load it.

## Quick start

1. Install the plugin as described under Install and uninstall below (two commands).
2. Restart Claude Code.
3. Start a session in one of your projects.
4. Look for the session-start line `ordo: load the ordo:workflow skill before your next reply (tiers, agents, skills).` Seeing it means the plugin is active.
5. Ask for a change that alters behaviour, for example "add a `--json` flag to the CLI". The first thing Claude prints is a one-line tier statement such as `Tier 1: two files, no contract change`; the work then follows that tier.

## Worked example

One measured run on 2026-11-18, with Opus 5.5 as the main session and Sonnet 5.5 for a helper. The figures describe that single run, not a promise: your cost and time depend on the task, the model and your settings.

- Sample project: 2 Python files, 42 lines (a small CLI, `summary.py`, and its test file with 2 tests), in a git repository, with the plugin loaded.
- Task prompt, verbatim: `Add a --json flag to summary.py that prints the same summary as a JSON object.`
- To repeat it (the run loaded the same plugin files from a checkout): `claude -p "<the prompt>" --output-format json --permission-mode auto --setting-sources project,local --plugin-dir ~/.claude/plugins/marketplaces/ordo-marketplace/plugins/ordo`
- `--setting-sources project,local` keeps other user-level plugins out, so the run shows ordo alone; that is why `--plugin-dir` loads it.
- Tier line: `Tier 1: one CLI flag in summary.py plus tests, no contract change.`
- Skills loaded: `ordo:workflow`, `ordo:tdd`, `ordo:goal`. Agents: `ordo:dev`, then `ordo:code-reviewer`.
- Review verdict: APPROVED, no findings. Tests: 5 pass (3 new). Nothing was committed; the run ended by asking whether to commit to a new branch.
- Cost: about USD 0.46. Wall time: about 81 s.
- The run used `--setting-sources project,local`; it may still have included the author's global `CLAUDE.md` (not confirmed).

## When not to use it

ordo adds process, and process costs time and tokens. Skip it, or switch parts of it off, when:

- the change is tiny and one-off (adding an asset, raising a version, changing doc wording, a direct "change X to Y"): Tier 0 already skips most of it, but even the tier statement is overhead you may not want;
- the script is a throwaway you will not keep;
- you want no review and no process at all: use `claude plugin disable`, or turn steps off with the switches below;
- cost matters more than review: each dev, review and acceptance step is a further model run; the `dev_helper_*`, `code_review_*`, `plan_review`, `qa_check` and `po_acceptance_*` switches turn them off one by one, and light mode (see Switches) keeps Tier 2 and drops the Tier 1 helper and review.

## Install and uninstall

### Install

1. Add the marketplace and install the plugin:

   ```bash
   claude plugin marketplace add gfarkas-ep/ordo
   claude plugin install ordo@ordo-marketplace
   ```

2. Optional: add the extra rules (sections 1-4 and 6 of `claude-md/CLAUDE.md`: the Karpathy-derived coding principles and the Truth Protocol) to your personal instructions. The tier workflow is not in that file any more; it comes from `ordo:workflow`. Open `~/.claude/plugins/marketplaces/ordo-marketplace/claude-md/CLAUDE.md` (where a GitHub-installed marketplace is cloned) or `claude-md/CLAUDE.md` in the repository, and merge the parts you want into `~/.claude/CLAUDE.md` by hand.

Restart Claude Code after installing. Updates: `claude plugin marketplace update ordo-marketplace`, then `claude plugin update ordo@ordo-marketplace`. Auto-update is off by default for this marketplace; turn it on in `/plugin` under Marketplaces (select ordo-marketplace, turn on auto-update).

### Uninstall

1. Remove the plugin: `claude plugin uninstall ordo@ordo-marketplace`
2. Remove the marketplace: `claude plugin marketplace remove ordo-marketplace`
3. Delete any `ordo <key>: ...` lines you added to your project `CLAUDE.md` or to `~/.claude/CLAUDE.md` (switches and settings); they do nothing once the plugin is gone. If you copied `claude-md/CLAUDE.md` into your own file, remove that text by hand.
4. Restart Claude Code.

To keep the plugin installed but inactive, run `claude plugin disable ordo@ordo-marketplace` instead; `claude plugin enable ordo@ordo-marketplace` turns it back on.

## Switches

Each switch turns off one rule or review step. All are on by default except `usage_log`, which is off by default. Set one with a line in the form `ordo <key>: on` or `ordo <key>: off`, alone on its line, in lower case, in the `CLAUDE.md` in the session's working directory or in your global `~/.claude/CLAUDE.md`. Only these two files are read: not `.claude/CLAUDE.md`, not `CLAUDE.local.md`, not parent directories. The project's `CLAUDE.md` beats `~/.claude/CLAUDE.md`; with no line the key is on. With no line, `usage_log` is off. A line with an unknown key or another value is ignored, and in one file the last valid line wins.

| Key | Default | Turns off |
|---|---|---|
| `guard_hook` | on | The Bash guard hook (see Safety hook) |
| `git_rules` | on | The two git rules: commit and push only with your permission; never rebase, merge with `--no-ff` |
| `eval_budget` | on | The cost figure and the spend clause in an `eval-plan` plan; the wall-time budget stays |
| `dev_helper_tier1` | on | The `ordo:dev` helper at Tier 1: the main session writes the code itself, test-first |
| `dev_helper_tier2` | on | The `ordo:dev` helper at Tier 2: the main session writes the code itself, test-first |
| `code_review_tier1` | on | The `ordo:code-reviewer` review at the end of Tier 1 work |
| `code_review_tier2` | on | The `ordo:code-reviewer` review after each Tier 2 task |
| `plan_review` | on | The dev, qa and po seats of the consult-panel and its synthesis; the plan is still saved and still needs your approval |
| `qa_check` | on | The `ordo:qa` end check of a Tier 2 task |
| `po_acceptance_tier1` | on | The `ordo:po` acceptance of Tier 1 work that went through refine; the goal then closes when you confirm its acceptance criteria |
| `po_acceptance_tier2` | on | The `ordo:po` acceptance of Tier 2 work; the goal then closes when you confirm its acceptance criteria |
| `stall_watch` | on | The watch and the progress reports for background helpers; the four brief rules stay |
| `usage_log` | off | The opt-in local usage log; `on` turns it on (see Usage log and feedback). It is never named in the `ordo: switched off:` line |

A step that is off is not required for "done", for the merge to the main branch or for closing a goal. The tier switches are independent: one tier off changes nothing at the other tier. `git_rules` and `guard_hook` are independent too: with only `git_rules` off, the Bash guard still denies `git rebase` and force push. Refine, diagnose, goal discipline and the session-start line itself have no switch. The whole plugin is turned off with `claude plugin disable`.

Switches that are off are named in one `ordo: switched off:` line at session start. For example `ordo: switched off: code_review_tier1 (project CLAUDE.md)`. The line exists because a `CLAUDE.md` line is not reliably in the session's context. See Goal hook.

The session itself can switch the guard off: it writes `ordo guard_hook: off` into `CLAUDE.md`, then runs the blocked command. This is accepted, not blocked; the switch is meant for your choice. The next session start names `guard_hook` as switched off, so you see it.

Light mode is an example, not a key. These two lines in a `CLAUDE.md`:

```
ordo dev_helper_tier1: off
ordo code_review_tier1: off
```

Copying these two lines into `CLAUDE.md` turns off the Tier 1 helper agent and Tier 1 code review and leaves Tier 2 untouched. Delete or flip the lines to turn Tier 1 back on.

## Safety hook

The plugin registers a PreToolUse hook on `Bash` (`plugins/ordo/hooks/hooks.json`, script `plugins/ordo/hooks/guard_bash.py`, python3, standard library only, no file writes, no network). The `usage_log.py` hook is also registered on `Bash`; it writes only when `usage_log` is on (see Usage log and feedback), and `guard_bash.py` itself never writes. It hard-denies exactly four command families and nothing else:

- any `git rebase` form;
- `git pull --rebase`, `git pull -r`, `git pull --rebase=<value>` (`--rebase=false` and `--rebase=no` pass);
- `git push` with `--force`, a short flag cluster containing `f` (`-fu`), `--force-with-lease[=...]`, `--force-if-includes`, or any `+refspec` (`origin +main`);
- `rm` with a recursive flag (`-r`, `-R`, `-rf`, `--recursive`) and a target of exactly `/`, `/*`, `~`, `~/`, `~/*`, `$HOME`, `${HOME}` (each also with `/` or `/*`) or your home path from the environment. `rm -rf ~/dev/x` and `rm /` (no recursive flag) pass.

Matching is on argv, so `git commit -m "no rebase"` and `echo "git push --force"` pass. Unquoted `#` comments and heredoc bodies are text, not commands, so a commit message that mentions `git rebase` passes; a heredoc whose body is executed (`bash <<EOF`, `cat <<EOF | bash`, `bash -c "$(cat <<EOF`) has its body checked and denied. The command is split on unquoted `;`, `&&`, `||`, `|`, `&`, parentheses and backticks; `sudo`, `env`, `K=V`, `git -C dir`, `git -c k=v`, the keywords `{ ! do then else elif if while until` and the `time`, `nohup`, `timeout` and `nice` wrappers are looked through; `bash|sh|zsh -c '...'` is parsed up to three levels deep (deeper, or a string that cannot be parsed, gets a raw regex scan for the same four families).

A deny is hard: Claude sees the rule and the reason, the command does not run, and there is no override flag. The guard is turned off by `ordo guard_hook: off` (see Switches); its two `CLAUDE.md` files are read only after a command matches one of the four families. To run a blocked command yourself, type it in the session with the `! <command>` prefix.

The hook fails open: invalid input or an internal error prints a warning to stderr ("failed open"), exits 0 and allows the command; it never exits 2. Plugin hooks also run inside subagents, so the same block applies to their Bash calls (platform docs; no eval covers this).

Known limits:

- With the working directory in a subdirectory, the project line is not found (only that directory's `CLAUDE.md` is read) and the guard stays on (fails safe).
- Not inspected: `eval`, shell variables (`$CMD`), scripts on disk, command substitution inside double quotes (`echo "$(git rebase main)"`), `env -S`, `find -exec`, `xargs`, the `command` and `exec` wrappers, a heredoc piped through a wrapper (`cat <<EOF | env bash`, `| xargs sh`, `tee x | sh`), and heredoc starts inside quotes or arithmetic (`'<<X'` or `$((1<<n))` can hide the lines that follow, as long as a line `X` closes it).
- Config-driven rebase (`pull.rebase=true`) is not seen: the hook reads only the command.
- Remaining false-positive sources: a quoted `"~"` or `'$HOME'` is treated like the unquoted form (it fails safe), a heredoc that reaches a shell is always treated as executed, a `bash -c`/`sh -c` earlier on the same line (even inside a quoted message) marks a later text heredoc as executed, and strings that cannot be tokenised fall back to a raw text scan that cannot tell prose from commands. Run the command yourself with `! <command>` in those cases.
- Nothing outside the four families is blocked (`git reset --hard`, `git branch -D` and other `rm` targets pass).
- Tested live only in the eval's `dontAsk` permission mode with Bash allowed (case `hook-blocks-rebase`); behaviour under auto or bypass permission mode is not covered. Eval scores are advisory with the hook active, because it loads in every eval.

## Goal discipline

Terms used by the architect text and `ordo:goal`:

- **Roadmap**: big-picture outcomes, ordered, months long, set by the user.
- **Goal**: one specific outcome for the current run.
- **Backlog**: the tasks of the current goal, in its plan; empty when the goal is done.
- **Low-priority list**: findings and ideas not needed for the current goal.
- **Lessons**: retro-proposed improvements to the working environment, kept for later review, never worked from.
- **Design**: how the system is built (the design document).
- **Spec**: what one piece of work must do, with acceptance criteria.
- **ADR**: a short record of one hard-to-reverse decision.

Three files, one purpose each: `ROADMAP.md` is worked from (current goal at the top, then the roadmap, then one line per done or cancelled goal); `LOW_PRIORITY.md` is worked from only when you promote an item; `LESSONS.md` is never worked from and is sorted only when you ask.

The plan of the current goal lives in the project at `docs/plans/<date>-<slug>.md`, so it survives a reboot and a compaction. The `## Current goal` section links it with a `Plan:` line right after the goal sentence, and the goal hook prints that line with the section.

Rules, in the `ordo:goal` skill and the reviewer agents (code-reviewer, qa, po):

- Round rule, counted per item: round 1, any finding may send the item back to dev; rounds 2 and 3, only the eight keep categories block (security; real or personal data; data loss; money or runaway cost loops; false-green tests; irreversible or live-infrastructure change; unmet acceptance criterion; architecture), every `other` finding goes to the low-priority list once; rounds 4 and 5 are not run automatically but go to you with what fails, what was tried, a best hypothesis and one recommendation (rerun dev or qa on a stronger model your environment names, for that round only, after your yes and only if you have access to it; change approach; or park); stop after round 5. Reviewers tag each finding with one category and the architect never re-tags. `architecture` counts only with a quoted principle and its source (file and section), otherwise the tag is `other`.
- Side-request rule: when you ask for something off the current goal, the architect states the cost to the goal in one line and asks "now or park?"; park adds a low-priority entry.
- Principle check: before briefing a fix for a finding, and before any question reaches you, the architect names the design principle it touches (cited) or states that no stated principle is touched. A fix that would break one is redesigned at the boundary; a question that touches one is put to you as the design question first.
- Judging requirements: drop what you add that the goal does not need (the user's requests and reviewers' findings follow their own rules), raise a genuine issue first, even if nobody asked.
- Questions to you are plain language with exactly one recommendation you can accept with "yes". Both formats count: the ba's `— Recommended:` and the goal skill's `Recommend:` line.
- Retro: approved lessons go to the `LESSONS.md` of the project where the retro runs, replacing the 0.7.0 memory backlog entry. Each saved lesson starts with the date it was saved. A lesson about the plugin is tagged "ordo plugin"; you carry it to the plugin repo by hand, or turn it into an add-on with `/ordo:improve` (see Add-ons and the self-improvement loop).
- Hook: see Goal hook below.

## Reading settings

The ba reads what it relies on in full. Only when the reading set is large may it hand groups of whole files (or line ranges, for one huge file) to `ordo:reader` helpers. Four values control this:

| Key | Default | Covers |
|---|---|---|
| `reader_threshold_tokens` | 200000 | Estimated tokens (bytes/4) below which the ba reads everything itself |
| `reader_threshold_files` | 10 | File count up to which the ba reads everything itself |
| `reader_cap_tokens` | 80000 | Estimated tokens per reader group |
| `reader_cap_files` | 10 | Files per reader group |

Set a value with one line per key, in the form `ordo <key>: <positive integer>`, for example `ordo reader_threshold_tokens: 200000`. Put the lines in the project's `CLAUDE.md` or in your global `~/.claude/CLAUDE.md`. The first level that sets a key wins: the brief (the dispatch prompt the architect writes), then the project `CLAUDE.md`, then the global `~/.claude/CLAUDE.md`, then the default. A line with an unknown key or a value that is not a positive integer is ignored.

## Watching helpers

Every helper agent or job the main session starts in the background is watched from launch, with no guess about how long it takes: a progress report every 10 minutes by default, and a stall at once as `stalled: <cause>, <action>`. The session may unblock a helper on its own (message it, stop a stuck child process it can name); stopping the helper itself needs your yes. With `watch_check_by` `script` (default), the script `plugins/ordo/skills/workflow/stall-check.sh` does the cheap checks without the model and wakes the session only on a suspect line or a report line; with `model`, the session runs each check itself. The rule lives in `ordo:workflow`. `ordo stall_watch: off` (see Switches) starts no watch and no reports; the four brief rules for helpers (no `nohup ... &`, wait loops with a failure exit, no self-matching `pgrep -f`, no command waiting on input that never comes) stay on.

| Key | Default | Covers |
|---|---|---|
| `watch_check_minutes` | 5 | Minutes between two checks |
| `watch_report_minutes` | 10 | Minutes between two progress reports |
| `watch_check_by` | script | `script` or `model`: who runs the checks |

Set a value with one line per key, in the form `ordo <key>: <value>`, for example `ordo watch_check_minutes: 5`; the number keys take a positive integer. The project `CLAUDE.md` beats `~/.claude/CLAUDE.md`; a line with another value is ignored and the next level or the default applies. A check interval of 10 minutes or more runs in `model` mode (one model turn per check): a Monitor lasts at most 30 minutes.

Known limits:

- A foreground helper cannot be watched; only your Esc stops it.
- A live run of a hung helper is not part of the plugin's tests.

## Add-on settings

| Key | Default | Covers |
|---|---|---|
| `addon_max_lines` | 40 | Most lines per add-on file |
| `addon_scope` | global | `global`, `project` or `ask` (asked once per run): the folder every add-on change is written to |

Set a value with one line per key, in the form `ordo <key>: <value>`, for example `ordo addon_scope: project`; `addon_max_lines` takes a positive integer. The project `CLAUDE.md` beats `~/.claude/CLAUDE.md`; a line with another value is ignored and the next level or the default applies.

## Add-ons and the self-improvement loop

An add-on is a short markdown file of bullet rules, named after one ordo skill or agent (`tdd.md`, `dev.md`), that adds to or replaces that skill's or agent's own rules for you. The base skills and agents are never edited, so plugin updates keep arriving and your changes stay small and reversible. Every skill and agent except `ordo:improve` and `ordo:coach` reads its own add-on files when it starts (the two settings above set the size limit and where new add-ons go).

Two places, one file per skill or agent in each:

- `~/.claude/ordo/addons/<name>.md`: global, for all your projects;
- `.claude/ordo/addons/<name>.md`: in the project.

Layer order: base, then global, then project. On a conflict the later layer wins; the earlier rule stays in its file untouched. A project add-on comes with the repository, like a project `CLAUDE.md`: you trust it as you trust that file, so read it before you work in a repository you do not know.

What no add-on can change, whatever it says: git permission, push, rebase, the guard hook, sending anything without your yes, and the yes before a paid eval.

`/ordo:improve` starts only when you ask for it and handles one lesson per run:

1. Lesson: you describe the behaviour to change, or pick one from a retro run in the conversation or a saved "ordo plugin" lesson in `LESSONS.md` (each shown with its date).
2. Coach screen: `ordo:coach` refuses a lesson that targets one of the things above, or reports one the base text or an add-on already covers; nothing is written and no paid run starts.
3. Your check of the case: the eval case is drafted, shown in full, and used only after your yes; after the yes it never changes.
4. Eval plan and your yes: the run is planned with `ordo:eval-plan` (stages, number of candidates, regression cases, budget, stop rule); no paid eval starts before your explicit yes.
5. Red check: the case must fail on the stack you have now; if it passes, it checks nothing and the run stops.
6. Candidates: the coach drafts candidate add-on files (2 by default, at most 3, as set in the eval plan), each one change from the current add-on.
7. Lesson round, 3/3: each candidate runs the case 3 times; a candidate below 3/3 is dropped.
8. Regression: each 3/3 candidate runs earlier accepted cases and the plugin's cases for the same skill or agent.
9. Your pick: a table shows each candidate with its results and diff; you pick one, reject all or drop the lesson. The add-on changes only after your pick.

You may decline the eval and accept a candidate anyway; it is then written as "not verified" and shown that way in the history.

Other things you can ask `/ordo:improve` for: the effective stack of a skill or agent (base, global and project rules in order, with the rules a later layer overrides marked); the history of an add-on (each saved version with its lesson and result); and a restore of a version you name (the file it replaces is saved to history first; restoring a "no previous add-on" entry removes the add-on, and you are warned before your yes). A run keeps its files next to your add-ons: lesson cases in `ordo/improve/evals/`, candidates in `ordo/improve/candidates/`, run results in `ordo/improve/runs/`, and add-on versions in `ordo/addons/history/`, under `~/.claude/` or the project's `.claude/`. After a verified change it offers a contributor PR (a draft, nothing sent without a further yes).

`improve-eval.sh`, the helper that writes the add-on and history files and starts the eval runs, is not in the usage log's script list: its runs are not logged.

Cost: paid eval runs happen only under an eval plan and after your yes. Declining the eval runs no paid eval; the coach still drafts candidates.

## Domain skills from other plugins or your project

A domain skill is a skill about your own subject (payment rules, an API style, a test naming scheme), not about how ordo works. ordo's agents can use one on top of ordo. A domain skill can live in three places:

- another plugin (named `plugin:skill`, for example `acme:pci-rules`);
- the project, in `.claude/skills/<name>/SKILL.md`;
- your user folder, in `~/.claude/skills/`.

Two routes bring a skill to an agent:

- The architect names it. Before it dispatches `ordo:dev`, `ordo:qa`, `ordo:code-reviewer`, `ordo:ba` or `ordo:po`, it checks the installed skills against the task. It puts each fitting skill in the brief as a `Domain skills:` line. When nothing fits, there is no line. Fix rounds and re-reviews repeat the line.
- The agent picks it. When the brief names no skill and an installed skill fits the task, the agent loads it itself and marks it `(picked)` in its report. An ordo skill, or a generic tdd, review, planning or spec skill, is never picked this way.

Every report of dev, qa, code-reviewer, ba and po has a `Domain skills:` line right after its Not verified part: the skills it loaded, `not loaded: <name>` for one that failed (the agent then carries on without it), or `none`. Later sections, such as one an add-on asks for, may follow it, and it is never folded into another section. The verdict or heading on the first line stays where it was.

To make sure a skill is always considered, add one line to the project `CLAUDE.md` or to `~/.claude/CLAUDE.md`:

| Key | Default | Covers |
|---|---|---|
| `domain_skills` | none | Skills the architect always considers, comma-separated |

For example `ordo domain_skills: acme:pci-rules, error-messages`. The project line replaces the global line (no merge); a line with an empty list, an empty name or a name with a space is ignored. A listed skill is considered, not forced: it is named only when it fits the task, and one that is not installed is skipped with a one-line note, so a typo shows.

Who wins: ordo's protected rules (git permission, push, rebase, the guard hook, sending anything only after your yes, the yes before a paid eval) and its process (tiers, review rounds, a read-only agent staying read-only, the fields of a report) come first. A domain skill may add its own lines at the end of a report, but never removes, renames or reorders an ordo field. Your add-ons come next. The domain skill wins on its own subject, such as code style or test naming.

`ordo:reader` and `ordo:coach` do not use domain skills.

Caution: project skills come with the repository, like a project `CLAUDE.md`, so read them before you work in a repository you do not know. The read-only agents can still run shell commands, so a hostile skill is a risk that only your reading of it guards against.

Project skills are not eval-tested, because the eval sandbox does not load them; a manual live check covers them.

## Goal hook

The plugin also registers a SessionStart hook (matcher `startup|resume|compact`, script `plugins/ordo/hooks/goal_context.py`, python3, standard library only, read-only). `usage_log.py` is also registered on SessionStart and writes only when `usage_log` is on. `goal_context.py` always prints one line telling the main session to load `ordo:workflow` before its next reply (the line comes first, whatever else happens). It then reads `ROADMAP.md` in the project directory (the hook's `cwd`, else the process cwd) and finds the first line that is exactly `## Current goal`. When that section has content, it prints `ordo: current goal (from ROADMAP.md). Load the ordo:goal skill before your next reply.` followed by the section (up to the next `## ` heading), capped at 15 lines and 1200 bytes; a cut ends with `…(truncated, see ROADMAP.md)`.

Apart from the `ordo: switched off:` line (see Switches), it prints only the workflow line when there is no `ROADMAP.md`, when it is unreadable or not UTF-8, or when the section is missing or empty. It fails open: any error means no output beyond the workflow line and the `ordo: switched off:` line (or nothing if even that cannot print), exit 0, nothing on stderr.

## Usage log and feedback

Both are opt-in and local. `usage_log` is never named in the `ordo: switched off:` line. Nothing leaves your machine unless you read the exact text and say yes.

Usage log. With `ordo usage_log: on` (same two `CLAUDE.md` files and rules as the other switches; with no line it is off, the only default-off key) the plugin's hooks append one JSON line per event to `~/.config/ordo/usage.jsonl`. The file is created readable only by you. It is plain text, one JSON object per line. Only the plugin's own skills, agents and scripts are logged, by their own names, with one exception: any Bash command that the guard would block writes a `guard` line (family and session code only), whether or not it runs an own script. A call to anything else writes nothing.

Line kinds (each line also has `time` and `kind`):

| `kind` | Written when | Other fields |
|---|---|---|
| `start` | a session starts with source `startup` or `clear` (`resume` and `compact` write none) | `session` |
| `end` | a session ends | `session` |
| `skill` | an own skill loaded through the Skill tool finished, failed, was aborted or was denied | `name`, `result`, `version`, `off`, `session`, `call` |
| `script` | an own script run through the Bash tool finished, failed, was aborted or was denied, or one started through the Monitor tool was started, failed, was aborted or was denied | `name`, `result`, `version`, `off`, `session`, `call`; `via` on a Monitor launch |
| `agent` | an own agent finished (the one line of a successful agent that counts as a run), or an Agent call of an own agent failed, was aborted or was denied | `name`, `result`, `version`, `off`, `session`; `agent` and `verdict` on a finish; `call` on a failed, aborted or denied call |
| `agent-start` | an own agent started | `name`, `session`, `agent` |
| `launch` | an Agent call of an own agent returned (for a background agent that is at launch) | `session`, `agent`, `call`, `round` |
| `ask` | Claude Code asked you for permission to run an own skill, agent or script | `target`, `name`, `version`, `off`, `session`, `call` |
| `call` | an own skill, agent or script is about to run | `target`, `name`, `session`, `call` |
| `guard` | the Bash guard blocked a command | `session`, `family` |

Fields (a line holds only these, nothing else):

- `time`: UTC, ISO format.
- `kind`: one of the kinds above.
- `name`: the skill, agent or script name; a script by its file name without directory and extension (`stall-check`, `usage-report`).
- `target`: on `ask` and `call` lines only: `skill`, `agent` or `script`.
- `result`: `ok` (the call finished), `failed` (it failed), `aborted` (it ended as an abort by the process) or `denied` (Claude Code refused it in auto mode). Only on `skill`, `script` and `agent` lines.
- `round`: the number in "Round N" of the agent's brief (at most 3 digits), on `launch` lines; absent when the brief has none.
- `version`: the plugin version.
- `off`: the keys of the 12 switches that are off (not `usage_log`).
- `session`: a short one-way code made from the session ID; never the ID itself. It pairs a `start` line with the next `end` line of the same session (session length). With no session ID in the payload the line has no `session` and no `call`.
- `call`: a short one-way code made from the session ID, the tool name and the tool input; never the command or any input itself. The same call in two sessions gets two codes. It links the `call` line, the `ask` line and the outcome line of one call.
- `agent`: a short one-way code made from the agent's ID; never the ID itself. It links the `agent-start`, `launch` and finish lines of one agent.
- `verdict`: one word (APPROVED, CHANGES, PASS, FAIL, ACCEPTED, REJECTED or ESCALATE), taken from the first non-blank line of a `code-reviewer`, `qa` or `po` reply, on a finish line. A reply that starts any other way gives no verdict; an agent that reports through the SubagentHandback tool may leave none.
- `family`: the rule family of a block by the Bash guard (`rebase`, `pull-rebase`, `force-push` or `rm-recursive`), on `guard` lines.
- `via`: the word `monitor`, on a `script` line written for a Monitor launch; Bash runs have no `via`.

Run time is not a field: the summary works it out as the finish time minus the start time of the same agent code, in whole seconds.

What is counted:

- A skill counts only when it is loaded through the Skill tool; a skill read or used in any other way is not counted.
- A plugin script (`stall-check`, `usage-report`) counts by its file name only, and only when the Bash tool runs it or the Monitor tool starts it (its absolute path, resolving to a script file under the plugin's `skills/<dir>/`, is the first word of a command segment, alone or behind `sh`, `bash`, `zsh`, `python` or `python3`; a relative path, an unexpanded variable or a `K=V` prefix is not counted; only the first line of the command is read). Neither the command text nor the script arguments are written. A Monitor launch of an own script counts as a run when it starts; its outcome is not reported, because Claude Code sends no hook when a Monitor ends.
- A run is a line with result `ok`, `failed` or `aborted`; for an agent it is the finish line, or a failed or aborted Agent call. The `agent-start` and `launch` lines are never runs.
- "Not allowed" is a call that was asked for permission and never ran. It also counts a prompt left unanswered until the session ended. "Cancelled" is a call that started, was never asked about and never reported an outcome, so you stopped it or the session ended (a killed session counts as cancelled). Claude Code reports neither of them, so the not-allowed count from a rejected or unanswered prompt and the cancelled count are inferred. An abort by the process is `aborted`, never cancelled. A denial in auto mode is reported: it is written with result `denied`. "Not allowed" never counts an auto-mode denial; "denied (auto mode)" is its own count and means Claude Code in auto mode refused the call (you did not). A denial settles the earlier prompt of the same call, so the call is counted once, as denied.
- A call that you allowed and then stopped while it ran looks like a rejected prompt, so it counts as not allowed, not as cancelled; the two cannot be told apart.
- An agent that started and never finished shows as "started, never finished": it is still running, was killed with the session, or was a background agent you stopped after launch (that stop shows only this way).

The summary of `ordo:feedback` (see below) shows, per own skill, agent and script: runs, failed, aborted, asked, ran, not allowed, denied (auto mode) and cancelled (agents also started, never finished), plus counts per verdict and guard family, agent run times and session length; a script that was started through Monitor shows "started through Monitor M (outcome not reported)", M being its Monitor launches. The codes are used to pair lines and are never printed.

Never logged: prompt text, agent output (apart from one verdict word), error text, the reason of a denial, permission suggestions, command text, script arguments, the interrupt flag itself (only the result `aborted` is written), code, file names (other than the name of an own script), paths, project names, the session ID, the agent ID, the tool input, and the names of skills, agents and scripts that are not the plugin's own.

Lines older than 90 days are removed the next time a line is written, and the summary ignores them. To read the log, open it with any editor or `cat`, or say `show my usage` (the `ordo:feedback` skill prints the summary). To clear it, ask the `ordo:feedback` skill in words (for example "clear my usage log"): it shows the path, the line count and the period, and deletes only that file after your yes. To turn logging off, set the line `ordo usage_log: off` in your project `CLAUDE.md` or in `~/.claude/CLAUDE.md` (the skill shows you the line; it edits no `CLAUDE.md`); the existing file stays until you clear it. The hooks make no network call and spawn no process; they fail open and print nothing.

`/ordo:feedback` runs only when you start it (nothing in the plugin starts it for you). It asks three plain questions (what happened, what you expected, anything else), builds a report with the labels of the bug template, adds the list of all 13 switches and the 10 value settings with their level (`project`, `global` or `default`; never a file path; whether or not `usage_log` is on), adds a usage summary when `usage_log` is on (you can drop it), removes paths, e-mail addresses and the terms of `~/.config/ordo/private-terms.txt` (best effort), prints the full text and sends nothing until you answer yes to that exact text. A GitHub issue is public and permanent. After a yes it sends with `gh issue create` when `gh` is installed, otherwise it prints the text and the new-issue link for you to paste. The repository address is read from the `repository` field of `plugin.json` (`https://github.com/gfarkas-ep/ordo`); when that field is not set, nothing is sent and the text is only printed. "Show my usage" prints the summary and sends nothing.

## Notes

- The `tdd` examples are in Python. The method is language-neutral.
- Agents load your global and project `CLAUDE.md` when they start, so project rules apply to them too.

## Credits

Reused sources (text copied or adapted, licence kept):

- [mattpocock/skills](https://github.com/mattpocock/skills): the `tdd`, `diagnose` and `grill` skills are adapted from it. MIT; each skill keeps its `LICENSE` file.
- [forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills): sections 1-4 of `claude-md/CLAUDE.md` are adapted from its `CLAUDE.md`. MIT per its README (no LICENSE file there); see `claude-md/LICENSE-andrej-karpathy-skills`.

## Licence

Community conduct: see `CODE_OF_CONDUCT.md`.

MIT, see `LICENSE`. Third-party parts keep their own licence files. Contributions are accepted under the same licence, see `CONTRIBUTING.md`.
