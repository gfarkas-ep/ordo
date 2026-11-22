#!/bin/bash
# Release checks for 0.13.0 (AC15, AC23, AC26, AC35, AC36, AC38; works-on-its-own AC9, AC10, AC12). Free: reads repo files only, no model call.
set -uo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root" || exit 2
command -v jq >/dev/null 2>&1 || { echo "test-release: jq is required" >&2; exit 2; }

pass=0; fail=0
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "FAIL: $1"; }
eq()  { [ "$2" = "$3" ] && ok || bad "$1 (expected '$2', got '$3')"; }
has() { grep -qF -- "$2" "$3" && ok || bad "$1: '$2' missing in $3"; }

plugin=plugins/ordo/.claude-plugin/plugin.json
market=.claude-plugin/marketplace.json
readme=README.md
changelog=CHANGELOG.md
contrib=CONTRIBUTING.md

# --- AC35: version, table, counts, notes ---
eq "plugin.json version" 0.13.0 "$(jq -r .version "$plugin" 2>/dev/null)"
eq "marketplace.json plugin entry has no version key (plugin.json is the only version)" false "$(jq -r '.plugins[0] | has("version")' "$market" 2>/dev/null)"
has "table row eval-plan" '`ordo:eval-plan`' "$readme"
has "table row retro" '`ordo:retro`' "$readme"
has "table row goal" '`ordo:goal`' "$readme"
has "table row workflow" '`ordo:workflow`' "$readme"
has "table row feedback" '`ordo:feedback`' "$readme"

num() { case "$1" in
  six) echo 6;; seven) echo 7;; eight) echo 8;; nine) echo 9;; ten) echo 10;; eleven) echo 11;; *) echo "?";; esac; }
skills_dirs=$(find plugins/ordo/skills -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
agents_files=$(find plugins/ordo/agents -mindepth 1 -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')
eq "skill dir count" 11 "$skills_dirs"
line3=$(sed -n 3p "$readme")
agents_word=$(printf '%s' "$line3" | sed -n 's/.*[. ]\([A-Za-z]*\) agents and \([a-z]*\) skills.*/\1/p' | tr 'A-Z' 'a-z')
skills_word=$(printf '%s' "$line3" | sed -n 's/.*agents and \([a-z]*\) skills.*/\1/p')
eq "README line 3 says eleven skills" eleven "$skills_word"
eq "README skills count matches dirs" "$skills_dirs" "$(num "$skills_word")"
eq "README agents count matches files" "$agents_files" "$(num "$agents_word")"
has "0.7.0 note" '- 0.7.0 ' "$changelog"
has "0.8.0 note" '- 0.8.0 ' "$changelog"
has "0.9.0 note" '- 0.9.0 ' "$changelog"
has "0.10.0 note" '- 0.10.0 ' "$changelog"
has "0.11.0 note" '- 0.11.0 ' "$changelog"
has "0.12.0 note" '- 0.12.0 ' "$changelog"
has "0.13.0 note (AC41)" '- 0.13.0 ' "$changelog"
has "hook section" '## Safety hook' "$readme"
has "eval-audit documented" 'scripts/eval-audit.sh' "$contrib"

# --- AC36: running the evals (scoped to that CONTRIBUTING line) ---
evals_line=$(grep -F -- '- Running the evals:' "$contrib" | head -1)
case "$evals_line" in *'(tag `bash-skills`) need `--scaffold` and `--allow-tools Bash`'*) ok;; *) bad "evals line lacks bash-skills '--allow-tools Bash'";; esac
for c in hook-blocks-rebase eval-plan-before-run eval-plan-after-run retro-proposes-only retro-no-autotrigger; do
  case "$evals_line" in *"\`$c\`"*) ok;; *) bad "evals line lacks $c";; esac
  stated=$(printf '%s' "${evals_line#*\`$c\`}" | grep -o '(tag `[a-z-]*`)' | head -1 | sed 's/(tag `\(.*\)`)/\1/')
  actual=$(sed -n 's/^tags: \[\(.*\)\].*/\1/p' "plugins/ordo/evals/$c/prompt.md" | head -1)
  eq "CONTRIBUTING tag for $c matches prompt.md" "$actual" "$stated"
done

# --- works-on-its-own T1: ordo:workflow skill (AC1, AC7, AC8) ---
wf=plugins/ordo/skills/workflow/SKILL.md
eq "workflow name" "name: workflow" "$(sed -n 2p "$wf" 2>/dev/null)"
has "workflow: short tier line without seams is the next output, before the required skill; no questions before refine" 'Your next output is the tier line as plain reply text: one short line, at most 20 words, in the form `Tier 1: two files, no contract change`, with nothing added to it. Keep the test seams out of that line and propose them later in the reply: longer text before a tool call may reach the user only as a summary that drops the tier. Only after that line, in the same reply, load the first skill the work requires (ordo:diagnose first for a bug or failure; otherwise ordo:refine for ambiguous or user-facing Tier 1 and for Tier 2; ordo:tdd for other Tier 1). This names only the first skill to load: ordo:goal is still loaded for Tier 1 and 2, as stated below. When the tier requires ordo:refine, ask the user nothing before it runs.' "$wf"
eq "workflow: last line is the never-rebase rule" '**Git: never rebase, merge only.**' "$(tail -n 1 "$wf" | cut -c1-34)"
has "workflow: architect role" 'In the main session you are the architect: you plan, set contracts and test seams, and delegate coding to the `ordo:dev` agent (unless that tier'\''s `dev_helper` switch is off).' "$wf"
has "workflow: tier line with seams" 'plus the proposed test seams for Tier 1 and 2' "$wf"
has "workflow: Tier 0 rule" '- **Tier 0**, no behaviour change' "$wf"
has "workflow: Tier 1 rule" '- **Tier 1**, behaviour change: load the `ordo:tdd` skill, delegate to `ordo:dev`' "$wf"
has "workflow: Tier 1 refine" 'run the `ordo:refine` skill before planning' "$wf"
has "workflow: Tier 2 rule" '- **Tier 2**, hard to reverse' "$wf"
has "workflow: Tier 2 consult-panel" 'then the `ordo:consult-panel` skill' "$wf"
has "workflow: Tier 2 done verdicts" 'Tier 2 is done only when `ordo:code-reviewer` has APPROVED every task' "$wf"
has "workflow: main branch production-ready" '**The main branch (master/main) is production-ready.**' "$wf"
has "workflow: feature branch" 'create a feature branch first' "$wf"
has "workflow: test-first via tdd" 'Every behaviour change ships test-first; the `ordo:tdd` skill is the method.' "$wf"
has "workflow: goal skill for Tier 1 and 2" 'For Tier 1 and 2 work, load the `ordo:goal` skill' "$wf"
has "workflow: diagnose for bugs and failures" 'load the `ordo:diagnose` skill before investigating' "$wf"
has "workflow: use these roles over other plugins" 'For these roles, use these agents and skills rather than similar ones from other plugins.' "$wf"
has "workflow: commit and push permission" '**Git: commit and push only with the user'\''s permission.**' "$wf"
has "workflow: never rebase, merge only" '**Git: never rebase, merge only.**' "$wf"
has "workflow: merge --no-ff" '`git merge --no-ff`' "$wf"
has "workflow: user's own CLAUDE.md wins (AC7)" 'Where the user'\''s own CLAUDE.md or a direct instruction from the user conflicts with this skill, the user'\''s file or instruction wins.' "$wf"
grep -qF 'fixed defaults; there is no switch to turn them off' "$wf" && bad "workflow still says the git rules have no switch (AC7)" || ok
# lighter-defaults T3a: switches in the workflow skill (AC7, AC8, AC12-AC15, AC17-AC21, AC43); key and step on one line
both() { grep -F -- "$3" "$4" | grep -qF -- "$2" && ok || bad "$1: '$2' and '$3' not on one line in $4"; }
has "workflow: switch line format" 'a line that is exactly `ordo <key>: on` or `ordo <key>: off`' "$wf"
has "workflow: project beats global, default on" 'The project line beats the global line; with no line the key is on.' "$wf"
has "workflow: where the switch lines are read" 'project CLAUDE.md or in `~/.claude/CLAUDE.md`' "$wf"
has "workflow: last valid line wins, other lines ignored" 'in one file the last valid line wins' "$wf"
both "workflow: session-start line named, step still checks its key (AC43)" '`ordo: switched off:`' 'each step still checks its own key' "$wf"
has "workflow: dev_helper_tier1 note at its step (AC12-AC19)" 'delegate to `ordo:dev` (skipped when `ordo dev_helper_tier1: off`: you write the code yourself, test-first, fix rounds included)' "$wf"
has "workflow: code_review_tier1 note at its step (AC12-AC19)" 'run `ordo:code-reviewer` once at the end (skipped when `ordo code_review_tier1: off`)' "$wf"
has "workflow: po_acceptance_tier1 note at its step (AC12-AC19)" '`ordo:po` acceptance at the end (skipped when `ordo po_acceptance_tier1: off`)' "$wf"
has "workflow: dev_helper_tier2 note at its step (AC12-AC19)" '`ordo:dev` per task (skipped when `ordo dev_helper_tier2: off`: you write the code yourself, test-first, fix rounds included)' "$wf"
has "workflow: code_review_tier2 note at its step (AC12-AC19)" '`ordo:code-reviewer` after each task (skipped when `ordo code_review_tier2: off`)' "$wf"
has "workflow: qa_check note at its step (AC12-AC19)" '`ordo:qa` before reporting done (skipped when `ordo qa_check: off`)' "$wf"
has "workflow: po_acceptance_tier2 note at its step (AC12-AC19)" '`ordo:po` acceptance (skipped when `ordo po_acceptance_tier2: off`)' "$wf"
both "workflow: Tier 2 done counts only the steps that are on (AC20)" 'Tier 2 is done only when' 'counting only the steps that are on' "$wf"
both "workflow: merge verdicts only for steps that are on (AC20)" 'A merge of Tier 2 work to the main branch needs' 'each only when its step is on' "$wf"
has "workflow: tiers independent (AC21)" 'A key that is off for one tier changes nothing at the other tier or at any other step.' "$wf"
both "workflow: git rules apply unless git_rules off (AC7)" 'ordo git_rules: off' 'The two git rules below apply unless' "$wf"
both "workflow: guard switch separate from git_rules (AC8)" 'ordo guard_hook: off' 'does not switch off the guard hook' "$wf"
[ "$(sed -n 3p "$wf" 2>/dev/null | cut -c1-13)" = "description: " ] && ok || bad "workflow line 3 is not a description"
if grep -qE '(^| )(I|my|me)( |$)' "$wf" 2>/dev/null; then bad "workflow text still has I/my/me"; else ok; fi

# watch-helpers T3a: "Watching helpers" in the workflow skill (AC1, AC2, AC4, AC5, AC10, AC11, AC14-AC19, AC24, AC27, AC28)
both "workflow watch: switch condition and same-response start (AC1, AC24)" 'Unless `ordo stall_watch: off` (switch rules above)' 'every helper agent or job started in the background gets a watch started in the same response, with no guess about how long it takes' "$wf"
has "workflow watch: long helpers go to the background (AC2)" 'Start helpers that may take long in the background.' "$wf"
has "workflow watch: main session not watched (AC4)" 'The main session is not watched.' "$wf"
has "workflow watch: foreground limit (AC5)" 'Limit: a foreground helper blocks the session and cannot be watched; only the user'\''s Esc stops it.' "$wf"
has "workflow watch: check minutes default 5 (AC11, AC14)" '`ordo watch_check_minutes: <positive integer>` (default 5)' "$wf"
has "workflow watch: report minutes default 10 (AC11, AC14)" '`ordo watch_report_minutes: <positive integer>` (default 10)' "$wf"
has "workflow watch: check_by values and default (AC15-AC17)" '`ordo watch_check_by: script|model` (default script)' "$wf"
has "workflow watch: project beats global, invalid ignored (AC14, AC17)" 'project CLAUDE.md beats ~/.claude/CLAUDE.md; any other value, or a value that is not a positive integer, is ignored and the next level or the default applies' "$wf"
has "workflow watch: Monitor command shape (AC10, AC15)" 'sh <this skill'\''s base directory>/stall-check.sh --transcript <the helper'\''s output file from its launch result> --check <check minutes x 60> --report <report minutes x 60>' "$wf"
both "workflow watch: --pid for a job, first output line is the PID (AC3)" '`--pid <pid>`' 'so that its first output line is its PID, e.g. `echo "pid $$"; <command>`' "$wf"
has "workflow watch: --file and --pattern options" '`--file <path>` for files or logs the helper writes, `--pattern <text>` for a process it must keep running (plain text)' "$wf"
has "workflow watch: Monitor timeout at maximum" 'the Monitor timeout at its maximum (30 minutes)' "$wf"
has "workflow watch: transcript path from launch result, never guessed (AC10)" 'The transcript path comes from the launch result, never guessed.' "$wf"
both "workflow watch: model mode is a recurring schedule at the check interval (AC16)" 'In `model` mode' 'recurring session schedule at the check interval' "$wf"
has "workflow watch: model mode checks (AC6, AC16)" 'transcript size by `wc -c`, cumulative CPU time of the session'\''s child processes, files, test counts' "$wf"
rules_para=$(grep -F -- 'Whatever `stall_watch` says, every brief to a helper that may run long shell commands carries four rules' "$wf")
[ -n "$rules_para" ] && ok || bad "workflow brief rules: the stall_watch-says paragraph is missing (AC24, AC27)"
brule() { case "$rules_para" in *"$2"*) ok;; *) bad "$1: '$2' not in the stall_watch-says paragraph";; esac; }
brule "workflow brief rule 1: no nohup (AC27)" 'no `nohup ... &` (use the tool'\''s background mode)'
brule "workflow brief rule 2: wait loop failure exit (AC27)" 'every wait loop has a failure exit (output file exists, process alive, maximum tries)'
brule "workflow brief rule 3: no self-matching pgrep, with the remedy (AC27)" 'no `pgrep -f` pattern that matches its own command line (bracket pattern, e.g. `[c]laude plugin eval`)'
brule "workflow brief rule 4: no wait on input (AC27)" 'no command that waits on input that never comes (a read on a pipe that never closes, a command waiting for a reply)'
has "workflow model mode: when to flag a stall (AC6, AC16)" 'Flag the helper as suspect when its transcript and files do not grow and no child process of the session gains CPU time between two checks, or when the transcript stays flat for 3 checks whatever the CPU says; CPU is cumulative CPU time (`ps -o time`), never `%cpu`; sizes come from `wc -c`, never mtime' "$wf"
eq "workflow: Watching helpers sits before the git rules (AC33)" "yes" "$(awk '/^\*\*Watching helpers\.\*\*/{w=NR} /^The two git rules below/{g=NR} END{print (w>0 && g>w) ? "yes" : "no"}' "$wf")"
has "dev.md section 5 wait-loop sentence unchanged (AC28)" 'Run commands that finish within the shell tool'\''s foreground limit in the foreground; run longer ones in the background and wait for the exit notification. Never hand-roll a wait loop without a failure exit: stop when the process has died, when the expected output never appears, or after a fixed number of tries.' plugins/ordo/agents/dev.md
has "qa.md section 3 wait-loop sentence unchanged (AC28)" 'Run commands that finish within the shell tool'\''s foreground limit in the foreground; run longer ones in the background and wait for the exit notification. Never hand-roll a wait loop without a failure exit: stop when the process has died, when the expected output never appears, or after a fixed number of tries.' plugins/ordo/agents/qa.md

# watch-helpers T3b: judging, actions, reports, re-arm, end, fallback (AC3, AC12, AC13, AC15, AC18, AC20-AC23, AC31); each pin is checked inside the Watching helpers section only
wsec=$(awk '/^\*\*Watching helpers\.\*\*/{p=1} /^The two git rules below/{p=0} p' "$wf")
wsec_has() { case "$wsec" in *"$2"*) ok;; *) bad "$1: string missing in the Watching helpers section: $2";; esac; }
wsec_has "workflow watch: suspect line judged from evidence and last tool call, tail -c (AC15, AC20)" 'On a `suspect:` line, judge stalled or busy from the line'\''s evidence and the helper'\''s last tool call (the end of its output file, read with `tail -c`, never the whole file).'
wsec_has "workflow watch: busy is no stall, watch goes on (AC23)" 'Busy (long test run, growing files, CPU time): no stall, the watch goes on.'
wsec_has "workflow watch: stall reported at once in the stalled form (AC13, AC20)" 'Stalled: tell the user at once, not at the next report, as `stalled: <cause>, <action>`.'
wsec_has "workflow watch: automatic unblock actions (AC21)" 'message the helper to unblock it, or stop a stuck child process it can name from the idle list and the last tool call (a self-matching wait loop, a reader on a pipe that never closes)'
wsec_has "workflow watch: unmatched idle child is reported, not stopped (AC21)" 'An idle child it cannot match to the last tool call: report and ask.'
wsec_has "workflow watch: stopping the helper needs the user first (AC22)" 'Stopping the helper itself loses its work: ask the user first and stop nothing before the answer.'
wsec_has "workflow watch: report line gives 2-3 lines from a real check (AC12)" 'On a `report:` line, send the user 2-3 lines built from that line and the helper'\''s last tool call (what it is doing; size, CPU time, test count), never a bare "still running".'
wsec_has "workflow watch: several helpers in one message (AC12)" 'Several helpers: one message, one entry each.'
wsec_has "workflow watch: suspect line with the expiry, stall first (AC31)" 'with a `suspect:` line in the same notice, handle the stall first, then re-arm'
wsec_has "workflow watch: completion notice ends the watch (AC3)" 'On the helper'\''s completion notice, stop its watch (stop the Monitor, or delete the schedule) and say nothing more about it.'
wsec_has "workflow watch: no Monitor falls back to model mode (AC18)" 'No Monitor tool: use `model` mode and tell the user in one line; no way to schedule either: tell the user the helper cannot be watched.'
wsec_has "workflow watch: no transcript path, /dev/null and pid or file (AC10)" 'No transcript path at launch: say so in the first report, pass `--transcript /dev/null` (the script requires the option), add `--pid` or `--file` when there is one (an agent with neither has child CPU time only), and treat flat-transcript lines as no evidence.'
wsec_has "workflow watch: date noted at start and each report (AC31)" 'Note `date +%s` when the watch starts and at each report.'
wsec_has "workflow watch: re-arm in the same response, same arguments (AC31)" 'When the Monitor expires while the helper runs, re-arm in the same response with the same arguments; when a report is due or overdue, send it now from the last check line and re-arm without `--next-report`, otherwise add `--next-report <seconds left to the next report>` (a positive number);'
wsec_has "workflow watch: never say watched without a live Monitor or schedule (AC31)" 'Never say a helper is watched without a live Monitor or schedule behind it.'
wsec_has "workflow watch: check interval of 10 minutes or more uses model mode" 'use `model` mode, and say so in one line, when `watch_check_minutes` is 10 or more: a Monitor ends before 3 flat checks'
wsec_has "workflow watch: model mode flags, reports, re-arms (AC11, AC12)" 'In `model` mode, a check that flags a suspect is handled like a `suspect:` line; at each report interval the check is followed by the 2-3 line report; a schedule that ended while the helper runs is re-armed.'
wsec_has "workflow watch: note line, transcript cannot be read" 'On a `note:` line (transcript cannot be read), tell the user in the next report and treat flat-transcript lines as no evidence, as for `/dev/null`.'
wsec_has "workflow watch: stall_watch change applies to later helpers" 'A change of `stall_watch` applies to helpers started after it.'

# --- item 10 T2: ordo:feedback skill text (AC18, AC20, AC24-AC38); the rules are pinned as imperatives, the live dialogue is not run ---
ph_repo='<owner''>/<repo>'
fb=plugins/ordo/skills/feedback/SKILL.md
eq "feedback name" "name: feedback" "$(sed -n 2p "$fb" 2>/dev/null)"
fb_desc=$(sed -n 3p "$fb" 2>/dev/null)
case "$fb_desc" in "description: "*"Use only when the user explicitly asks for it"*"Never offer it and never run it on your own."*) ok;; *) bad "feedback description lacks the explicit-ask and never-offer sentences (AC24): $fb_desc";; esac
fb_sec() { # name heading-prefix string: the string must sit inside that section of the skill
  local sec; sec=$(awk -v h="$2" 'index($0,h)==1{p=1;next} /^## /{p=0} p' "$fb" 2>/dev/null)
  case "$sec" in *"$3"*) ok;; *) bad "feedback: $1: '$3' missing in section '$2'";; esac
}
fb_sec "start only on the user's ask, no offer (AC24)" '## Rules' 'Start this skill only when the user asks for it in this conversation (`/ordo:feedback` or feedback, a report, usage or the usage log in words). Never offer it, never suggest it and never start it on your own.'
fb_sec "nothing sent without a yes on the exact text (AC31, AC32)" '## Rules' 'Send nothing anywhere before the user has said an explicit yes to the exact text you printed. A no, an unclear answer or no answer means nothing is sent.'
fb_sec "only network action is the gh issue create (AC38)" '## Rules' 'The only network action this skill may take is the `gh issue create` of the Send step.'
fb_sec "sources of facts: the ordo key lines only through the settings command, no transcript, no hostname (AC38)" '## Rules' 'Gather facts only from this conversation, the usage file (through the helper), the plugin'\''s own `plugin.json`, `claude --version`, the operating system name, the `ordo <key>:` lines of the project and global `CLAUDE.md` (only through `usage-report.py settings`; nothing else from those files) and the private-terms list (through the helper). Read no transcript file. Never read, ask for or print the hostname.'
fb_sec "settings from the helper, in the project dir, level names only (AC52)" '## Report an issue' 'from `usage-report.py settings` run from the project'\''s working directory (the session'\''s working directory): one line per setting with its value and its level `project`, `global` or `default`, never a file path.'
fb_sec "settings list covers all 13 switches and 7 values, logging on or off (AC52)" '## Report an issue' 'It lists all 13 switches and the 7 settings that hold a value, whether or not usage logging is on.'
fb_sec "settings output goes under the section label unchanged (AC26, AC52)" '## Report an issue' 'Under `### ordo switches and settings in use` put the output of `usage-report.py settings` unchanged.'
fb_sec "settings list stays when the summary is dropped (AC28)" '## Report an issue' 'The settings list is not part of the summary and stays in the text when the summary is dropped.'
fb_sec "redaction covers the settings list and the summary (AC29)" '## Report an issue' 'the whole text, title included, with the settings list and the summary in it, goes through `usage-report.py redact`.'
fb_sec "redact: draft written with the file tool, one exact counted command (hook counts a ;-separated part)" '## Report an issue' 'write the text into `$dir/draft` with the file-writing tool, and run exactly this one-line command, with the path `mktemp -d` printed in place of `<path>`: `dir='\''<path>'\''; python3 <base directory of this skill>/usage-report.py redact < "$dir/draft"`.'
fb_sec "redact: other forms are not counted" '## Report an issue' 'so `dir=<path> python3 ...`, a command split over two lines and a multi-line quoted string piped into the helper are not counted.'
fb_sec "redact: temp directory deleted" '## Report an issue' 'Delete `$dir` afterwards.'
case "$(awk '/^## Report an issue/{p=1;next} /^## /{p=0} p' "$fb" 2>/dev/null)" in *'redact'*'| usage-report'*|*'printf'*'| python3'*|*'echo'*'| python3'*) bad "feedback: the redact step pipes text into the helper (the usage hook would not count the run)";; *) ok;; esac
grep -qF 'switched off' "$fb" 2>/dev/null && bad "feedback still reads the switched-off line of session start (AC52: the settings command is the source)" || ok
fb_sec "redaction before the first display (AC29)" '## Rules' 'Run the redaction before the first display of any text and on every text you show again.'
fb_sec "three plain questions (AC25)" '## Report an issue' 'Ask the three questions in plain words, in one message: what happened, what the user expected, and anything else that matters.'
fb_sec "rule or step asked once, unknown allowed (AC25)" '## Report an issue' 'When the conversation does not show which ordo rule or step was involved, ask once; "unknown" is an answer.'
fb_sec "answers as written (AC25)" '## Report an issue' 'Put the answers into the report as the user wrote them.'
fb_sec "version facts (AC25, AC38)" '## Report an issue' 'run `claude --version`; get the operating system name with `uname -sr` and never run `hostname` or `uname -a`'
fb_sec "bug template labels (AC26)" '## Report an issue' '`### Plugin version`, `### Claude Code version`, `### Operating system`, `### Steps to reproduce`, `### Expected result`, `### Actual result`, `### ordo switches and settings in use`'
fb_sec "usage summary through the helper (AC27)" '## Report an issue' 'summary --days 30'
fb_sec "no summary: one line, no urging (AC28)" '## Report an issue' 'say in one line that there is no usage summary, and do not urge the user to turn logging on.'
fb_sec "summary can be dropped (AC28)" '## Report an issue' 'The user may drop the summary at any time; the final text then holds none.'
fb_sec "redact through the helper, note line (AC29, AC30)" '## Report an issue' 'usage-report.py redact'
fb_sec "terms list not used: one line (AC30)" '## Report an issue' 'tell the user in one line that the private-terms list was not used'
fb_sec "full text, best effort, public and permanent (AC31)" '## Report an issue' 'Print the full text, never a summary of it.'
fb_sec "public-and-permanent note (AC31)" '## Report an issue' 'A GitHub issue is public and permanent.'
fb_sec "best-effort note (AC31)" '## Report an issue' 'Automatic removal of paths, e-mail addresses and private terms is best effort.'
fb_sec "explicit yes on that exact text (AC31)" '## Report an issue' 'Ask for an explicit yes to send exactly this text.'
fb_sec "edit shows again and asks again (AC32)" '## Report an issue' 'After any edit, run the redaction again, print the new full text again and ask again; the old yes does not carry over.'
fb_sec "no, unclear or silence sends nothing (AC32)" '## Report an issue' 'Treat "no", an unclear answer and no answer as no: send nothing.'
fb_sec "repository field decides (AC33, AC35)" '## Send' 'Read the `repository` field of the plugin'\''s own `plugin.json`.'
fb_sec "no gh call when repository is not set (AC35)" '## Send' 'make no `gh` call, print no link, print the approved text and say the repository address is not set yet.'
fb_sec "gh missing: no call, no login (AC34)" '## Send' 'make no call, never start a login'
fb_sec "gh paste path prints text and new-issue link with the reason (AC34)" '## Send' 'print the approved text and the new-issue link `https://github.com/OWNER/REPO/issues/new` with the reason'
fb_sec "gh issue create on the repository, exact text (AC33)" '## Send' 'gh issue create --repo'
fb_sec "no labels (AC33)" '## Send' 'Set no labels.'
fb_sec "title is the approved text after Title:, never the raw answer (AC31, AC33)" '## Send' 'The title is the text after `Title: ` on the first line of the approved text, unchanged: never the user'\''s raw answer.'
fb_sec "body is the approved text after the first line (AC33)" '## Send' 'The body is the approved text after that first line, unchanged.'
fb_sec "title and body only through files written by the file tool (security)" '## Send' 'Never put the title or the body into a shell command line or a here-document.'
fb_sec "files written with the file-writing tool, not the shell (security)" '## Send' 'with the file-writing tool, not the shell'
fb_sec "documented send command reads the files (security)" '## Send' 'gh issue create --repo "$repo" --title "$(cat "$dir/title")" --body-file "$dir/body"'
fb_sec "files and directory deleted after sending (security)" '## Send' 'Then delete the two files and the directory.'
send_sec=$(awk '/^## Send/{p=1;next} /^## /{p=0} p' "$fb" 2>/dev/null)
case "$send_sec" in *'<<'*) bad "feedback: Send step still holds a here-document (security)";; *) ok;; esac
fb_sec "summary only when usage_log is on (AC27, AC28)" '## Report an issue' 'Only when it prints `usage_log: on`, run `usage-report.py summary'
fb_sec "switch command read first (AC28)" '## Report an issue' 'Run `usage-report.py switch`.'
fb_sec "removed items stay removed, the user may add them on GitHub (AC29, AC32)" '## Report an issue' 'Tell the user that anything removed stays removed in the text, and that they can add it on GitHub after sending if they truly want it.'
fb_sec "print the issue address (AC33)" '## Send' 'Print the address of the new issue.'
fb_sec "gh error: show, print the text and link, no retry, no login (AC34, AC36)" '## Send' 'show the error, print the approved text and the new-issue link, start no login and do not retry unless the user asks.'
fb_sec "no auth check, no token (AC38)" '## Send' 'Never run `gh auth status` or `gh auth token`: the check that `gh` is installed is the only check before the call.'
sec_auth=$(grep -F 'gh auth' "$fb" 2>/dev/null | grep -vF 'Never run' || true)
[ -z "$sec_auth" ] && ok || bad "feedback has a gh auth line that is not a ban (AC38): $sec_auth"
if grep -qiE '(offer|suggest|recommend|propose)[a-z]* (this|the|that) (skill|feedback)|(offer|suggest)[a-z]* (/?ordo:)?feedback' "$fb" 2>/dev/null; then bad "feedback skill tells the session to offer or suggest itself (AC24)"; else ok; fi
fb_sec "show my usage: summary only, no send, no gh, no write (AC37)" '## Show my usage' 'Print the summary and nothing else: no send step, no `gh` call, no write.'
fb_sec "clear: show path, lines and period first (AC18)" '## Clear my usage log' 'Run `usage-report.py clear-info` and show its output (the file path, the number of lines and the period they cover)'
fb_sec "clear: delete only after an explicit yes (AC18)" '## Clear my usage log' 'Run `usage-report.py clear --yes` only after the user has answered yes to that question. With no yes, or no answer, delete nothing.'
fb_sec "clear: only usage.jsonl, never on its own (AC18)" '## Clear my usage log' 'Delete only `~/.config/ordo/usage.jsonl`, never another file, and never start a clear on your own.'
fb_sec "clear: nothing to delete (edge case)" '## Clear my usage log' 'say there is nothing to delete and stop'
fb_sec "turn off: show the exact line (AC20)" '## Turn logging off' 'Show the exact line `ordo usage_log: off` and say it goes on its own line in the `CLAUDE.md` of the project or in `~/.claude/CLAUDE.md`.'
fb_sec "turn off: edit no CLAUDE.md (AC20)" '## Turn logging off' 'Edit no `CLAUDE.md` yourself'
if grep -rqiE 'opus|sonnet|fable' plugins/ordo/skills/feedback/ 2>/dev/null; then bad "a model name is in the feedback skill (AC24)"; else ok; fi
if grep -rqF -- "$ph_repo" plugins 2>/dev/null; then bad "the repo placeholder sits under plugins/ (AC44)"; else ok; fi

# --- AC15 / AC23: frontmatter ---
eq "retro name" "name: retro" "$(sed -n 2p plugins/ordo/skills/retro/SKILL.md)"
eq "eval-plan name" "name: eval-plan" "$(sed -n 2p plugins/ordo/skills/eval-plan/SKILL.md)"

# --- AC1: glossary defined in the goal skill and in README ---
eq "goal name" "name: goal" "$(sed -n 2p plugins/ordo/skills/goal/SKILL.md)"
for t in Roadmap Goal Backlog Low-priority\ list Lessons Design Spec ADR; do
  has "goal skill defines $t" "- **$t**" plugins/ordo/skills/goal/SKILL.md
  has "README defines $t" "**$t**" "$readme"
done

# --- AC1 negative: no agent or skill file (except goal) uses backlog/roadmap/lessons for anything else ---
# Rule: after removing the file names ROADMAP.md and LESSONS.md, "backlog" and "roadmap" must not appear
# in any agent file or skill .md file (SKILL.md and helpers) other than skills/goal; "lesson(s)" is allowed only in skills/retro
# (it defines what retro proposes, in its SKILL.md). Matching is case-insensitive, whole words.
glossary_hits() { # file...; prints "file:line:text" for each forbidden use
  local f pat
  for f in "$@"; do
    pat='backlog|roadmap|lessons?'
    case "$f" in */skills/retro/SKILL.md) pat='backlog|roadmap';; esac
    sed -E 's/ROADMAP\.md|LESSONS\.md//g' "$f" | grep -niwE "$pat" | sed "s|^|$f:|"
  done
}
planted=$(mktemp); printf 'Ordo plugin: add a backlog entry in memory.\n' > "$planted"
[ -n "$(glossary_hits "$planted")" ] && ok || bad "glossary check does not catch a planted 'backlog entry in memory'"
rm -f "$planted"
files=$(ls plugins/ordo/agents/*.md plugins/ordo/skills/*/*.md | grep -v '^plugins/ordo/skills/goal/')
# shellcheck disable=SC2086
hits=$(glossary_hits $files)
[ -z "$hits" ] && ok || bad "glossary terms used outside the goal skill: $hits"

# --- T2b: pointers, plan fields, question rule, retro destination ---
for f in refine consult-panel; do has "$f points to ordo:goal" 'ordo:goal' "plugins/ordo/skills/$f/SKILL.md"; done
has "plan field Current goal" '**Current goal**' plugins/ordo/skills/consult-panel/SKILL.md
has "plan field Cheapest real test" '**Cheapest real test**' plugins/ordo/skills/consult-panel/SKILL.md
has "ba question rule" 'one sentence ending in "?"' plugins/ordo/agents/ba.md
has "panel question rule" 'one sentence ending in "?"' plugins/ordo/skills/consult-panel/SKILL.md
has "retro writes LESSONS.md" 'LESSONS.md' plugins/ordo/skills/retro/SKILL.md
has "retro tag" '"ordo plugin"' plugins/ordo/skills/retro/SKILL.md
retro_line=$(grep -F '`ordo:retro`' "$readme" | head -1)
case "$retro_line" in *LESSONS.md*) ok;; *) bad "README retro line lacks LESSONS.md";; esac

# --- AC26: README documents round rule, side-request rule, principle check, question formats, retro change, hook ---
has "README round rule 2-3 keep categories" 'rounds 2 and 3' "$readme"
has "README round rule 4-5 to the user" 'rounds 4 and 5' "$readme"
has "README round rule stronger model, no names (AC24)" 'rerun dev or qa on a stronger model your environment names, for that round only, after your yes and only if you have access to it' "$readme"
has "README round rule stop after 5" 'stop after round 5' "$readme"
has "README side-request rule" '"now or park?"' "$readme"
has "README principle check" 'Principle check' "$readme"
has "README question format ba" '— Recommended:' "$readme"
has "README question format goal" '`Recommend:`' "$readme"
# --- T5: question format never sent back for format alone; missing ROADMAP.md is not a stop ---
has "goal rule: ba format meets the rule" 'meets the format' plugins/ordo/skills/goal/SKILL.md
has "goal rule: never for format alone" 'never for format alone' plugins/ordo/skills/goal/SKILL.md
has "refine exception: never for format alone" 'never for format alone' plugins/ordo/skills/refine/SKILL.md
has "goal: no ROADMAP.md is not a stop" 'No `ROADMAP.md` while the user' plugins/ordo/skills/goal/SKILL.md
has "goal: no goal anywhere asks" 'no goal named anywhere' plugins/ordo/skills/goal/SKILL.md
has "goal: side request cost line" 'one line starting `Cost to the goal:`' plugins/ordo/skills/goal/SKILL.md
if grep -rqiE 'opus|sonnet|fable' plugins/ordo/skills/; then bad "a model name is in plugins/ordo/skills/ (AC24)"; else ok; fi
both "goal: round 4/5 names the helper's normal model (AC25)" 'Rounds 4 and 5' 'name the model the helper normally runs on' plugins/ordo/skills/goal/SKILL.md
both "goal: round 4/5 lists stronger models from the environment text (AC25)" 'Rounds 4 and 5' 'list the stronger models your environment text names, recommend one, and ask whether the user has access to it' plugins/ordo/skills/goal/SKILL.md
both "goal: round 4/5 stronger model only after a yes, that round only (AC25)" 'Rounds 4 and 5' "Use a stronger model only after the user's yes, for that round only" plugins/ordo/skills/goal/SKILL.md
both "goal: round 4/5 with no stronger model named (AC26)" 'Rounds 4 and 5' 'No stronger model named in your environment text: say so and offer only the normal model, change the approach or park.' plugins/ordo/skills/goal/SKILL.md
both "goal: round 4/5 rest of the rule stays (A5)" 'Rounds 4 and 5' 'do not dispatch. Go to the user with what fails, what was tried, your best hypothesis and one recommendation' plugins/ordo/skills/goal/SKILL.md
both "goal rule 2: po acceptance off, user confirms the criteria (AC20)" '`ordo po_acceptance_tier1` or `ordo po_acceptance_tier2` is off' "the goal closes when the user confirms its acceptance criteria are met" plugins/ordo/skills/goal/SKILL.md
has "goal: Fixing a finding checks the finding is true (AC27)" 'first check that the finding is true against the code' plugins/ordo/skills/goal/SKILL.md
has "goal: wrong finding gets no fix brief, evidence in the re-check brief (AC28)" 'A wrong finding gets no fix brief: answer the reviewer with the evidence (file:line or command output) in the re-check brief.' plugins/ordo/skills/goal/SKILL.md
has "goal: kept dispute goes to the user, stays open (AC30)" 'it goes to the user (plain language, one recommendation) and stays open until the user answers' plugins/ordo/skills/goal/SKILL.md
fixing=$(sed -n '/^## Fixing a finding/,/^## Cheapest/p' plugins/ordo/skills/goal/SKILL.md)
case "${fixing%%principle(s)*}" in *'check that the finding is true'*) ok;; *) bad "goal: the true-check does not come ahead of the principle check (AC27)";; esac
[ "$(grep -cF 'under the project'\''s git rules (`ordo git_rules`' plugins/ordo/skills/goal/SKILL.md)" = 2 ] && ok || bad "goal: the two commit lines do not point to the git_rules switch (AC7)"
has "goal: normal model only if the user picks that" 'runs on the normal model only if the user picks that' plugins/ordo/skills/goal/SKILL.md
has "README hook goal_context" 'goal_context.py' "$readme"
has "README retro change" 'replacing the 0.7.0 memory backlog entry' "$readme"
has "README principle check: no stated principle" 'no stated principle is touched' "$readme"
has "CHANGELOG 0.8.0 note names po for the question rule" 'plain-question rule in `ba`, `po` and `consult-panel`' "$changelog"
round_line=$(grep -F -- '- Round rule, counted per item' "$readme" | head -1)
for cat in 'security' 'real or personal data' 'data loss' 'money or runaway cost loops' 'false-green tests' 'irreversible or live-infrastructure change' 'unmet acceptance criterion' 'architecture'; do
  case "$round_line" in *"$cat"*) ok;; *) bad "README round-rule line lacks category '$cat'";; esac
done
case "$round_line" in *[Oo]pus*|*[Ss]onnet*|*[Ff]able*) bad "README round-rule line names a model (AC24)";; *) ok;; esac
# the six new case prompts must agree with README: no scaffold_script, so no '--scaffold' requirement
for c in side-request-now-or-park question-plain-one-rec round2-wording-not-blocking round2-keep-still-blocks round4-asks-user round2-history-auto-runs; do
  f="plugins/ordo/evals/$c/prompt.md"
  [ -f "$f" ] && ok || bad "$f missing"
  [ ! -f "plugins/ordo/evals/$c/case.yaml" ] && ok || bad "$c has a case.yaml (README says no scaffold_script)"
  # any --scaffold on the requires line must be written as "no --scaffold"
  if grep '^# requires:' "$f" | sed 's/no --scaffold//g' | grep -q -- '--scaffold'; then bad "$c requires comment asks for --scaffold, README says none"; else ok; fi
done

# --- AC38 ---
credit='<!-- Sections 1-4 adapted from forrestchang/andrej-karpathy-skills (MIT, https://github.com/forrestchang/andrej-karpathy-skills); see LICENSE-andrej-karpathy-skills. -->'
eq "claude-md/CLAUDE.md first line is the credit comment" "$credit" "$(sed -n 1p claude-md/CLAUDE.md)"
# works-on-its-own AC9: sections 1-4 and 6 pinned to hashes of the old file (git show main:claude-md/CLAUDE.md before this change); note present, section 5 gone
sec14() { awk '/^## 1\. /{p=1} /^## 5\. |^# Other general directions/{p=0} p' claude-md/CLAUDE.md; }
sec6()  { awk '/^## 6\. /{p=1} p' claude-md/CLAUDE.md; }
eq "claude-md sections 1-4 byte-identical" f43a7f6b0a7b7b6a290d380dd905403e1cc9e3c9 "$(sec14 | git hash-object --stdin)"
eq "claude-md section 6 byte-identical" e081a6d0975fe92ac896a48370c7e1eb0b38f433 "$(sec6 | git hash-object --stdin)"
eq "claude-md whole file minus note equals old file minus section 5" de5a11f2c44febe03bfd382b88a284a48e2c7cfb "$(sed '2,3d' claude-md/CLAUDE.md | git hash-object --stdin)"
has "claude-md note: workflow ships as the skill" 'The workflow now ships as the `ordo:workflow` skill in the plugin. This file is optional extras (sections 1-4 and 6).' claude-md/CLAUDE.md
eq "claude-md note sits on line 2" "The workflow now ships as the \`ordo:workflow\` skill in the plugin. This file is optional extras (sections 1-4 and 6)." "$(sed -n 2p claude-md/CLAUDE.md)"
grep -q '^## 5\. ' claude-md/CLAUDE.md && bad "claude-md still has section 5" || ok
grep -qF 'How We Work' claude-md/CLAUDE.md && bad "claude-md still says How We Work" || ok
# The 0.7.0 check "no LICENSE file added" is retired: licence notice files are allowed since the legal goal.

# --- manifests ---
for f in "$plugin" "$market"; do
  jq -e . "$f" >/dev/null 2>&1 && ok || bad "$f not valid JSON"
done
for d in "$(jq -r .description "$plugin" 2>/dev/null)" \
         "$(jq -r .description "$market" 2>/dev/null)" \
         "$(jq -r '.plugins[0].description' "$market" 2>/dev/null)"; do
  for w in eval-plan retro workflow "goal and retro skills" "Bash guard hook" "goal hook" "feedback report" "usage log"; do
    case "$d" in *"$w"*) ok;; *) bad "description lacks '$w': $d";; esac
  done
done

# --- works-on-its-own AC10: README ---
has "README line 24 points to ordo:workflow" 'The tier workflow that ties them together is the `ordo:workflow` skill' "$readme"
grep -qF 'lives in `claude-md/CLAUDE.md`' "$readme" && bad "README still says the workflow lives in claude-md/CLAUDE.md" || ok
has "README install step 2 optional" 'Optional: add the extra rules (sections 1-4 and 6 of `claude-md/CLAUDE.md`' "$readme"
grep -qF 'A plugin cannot ship a `CLAUDE.md`' "$readme" && bad "README install still says a plugin cannot ship a CLAUDE.md" || ok
has "README hook always prints workflow line" 'always prints one line telling the main session to load `ordo:workflow`' "$readme"
has "README hook prints only the workflow line" 'prints only the workflow line when there is no `ROADMAP.md`' "$readme"
has "CHANGELOG 0.9.0 note names the skill" 'adds the `workflow` skill' "$changelog"

# --- working-record checks: they read docs/specs and docs/decisions, neither of which ships in the public export ---
# A skip must never hide a tracked file: if docs/specs is absent but git lists files in docs/specs or docs/decisions, fail.
eq "docs/specs absent while git tracks files in docs/specs or docs/decisions (a skip hides nothing)" "" "$([ -d docs/specs ] || git ls-files docs/specs docs/decisions 2>/dev/null | head -1)"
if [ -d docs/specs ]; then
  # --- works-on-its-own AC12: goal-discipline spec amended with a pointer ---
  gspec=docs/specs/2026-11-15-goal-discipline.md
  ptr='(amended by docs/specs/2026-11-15-works-on-its-own.md)'
  scope='(scoped to the goal-discipline goal; claude-md/CLAUDE.md is changed by docs/specs/2026-11-15-works-on-its-own.md)'
  for pre in '- AC26:' '- Edits to `~/.claude/CLAUDE.md`, and edits to repo'; do
    case "$(grep -F -- "$pre" "$gspec" | head -1)" in *"$scope"*) ok;; *) bad "goal-discipline line '$pre' lacks the scoped note";; esac
  done
  has "goal-discipline A2: workflow line first, then goal" 'it prints the workflow line first, then, when a current goal exists,' "$gspec"
  for pre in '- AC12:' '- No ROADMAP.md at session start or compaction:' '- ROADMAP.md exists with no current goal:' '- A2:'; do
    l=$(grep -F -- "$pre" "$gspec" | head -1)
    case "$l" in *"$ptr"*"prints only the workflow line"*|*"prints only the workflow line"*"$ptr"*) ok;; *) bad "goal-discipline line '$pre' lacks pointer and 'prints only the workflow line'";; esac
  done

  eq "bash guard ADR byte-identical to main (AC37)" cf2278abb6c64ec12492fae1ceb65474595deae5 "$(git hash-object docs/decisions/2026-11-10-plugin-bash-guard-hook.md)"
  [ -f docs/decisions/2026-11-16-guard-switch.md ] && ok || bad "new guard switch ADR missing (AC37)"
  lptr='(amended by docs/specs/2026-11-16-lighter-defaults.md)'
  ptr_line() { # name file line-prefix
    local l; l=$(grep -F -- "$3" "$2" | head -1)
    case "$l" in *"$lptr"*) ok;; *) bad "$1: line '$3' of $2 lacks the lighter-defaults pointer";; esac
  }
  ptr_line "goal-discipline AC3 (AC36)" "$gspec" '- AC3: Given the current goal'
  ptr_line "goal-discipline AC16 (AC36)" "$gspec" '- AC16: Given round 4 or round 5'
  ptr_line "goal-discipline AC18 (AC36)" "$gspec" '- AC18: Given the architect wants a higher model'
  ptr_line "goal-discipline Opus edge case (AC36)" "$gspec" '- User says yes to Opus in round 4'
  ptr_line "goal-discipline Fable edge case (AC36)" "$gspec" '- User has no access to Fable at round 5'
  ptr_line "goal-discipline higher-model business rule (AC36)" "$gspec" '- A higher model is used per round only'
  ptr_line "goal-discipline A15 (AC36)" "$gspec" '- A15: The higher-model option is per round'
  ptr_line "goal-discipline AC19 (AC36)" "$gspec" '- AC19: Given the Tier 2 done rule'
  ptr_line "goal-discipline AC27 (AC36)" "$gspec" '- AC27: Given delivery'
  wspec=docs/specs/2026-11-15-works-on-its-own.md
  ptr_line "works-on-its-own AC8 (AC36)" "$wspec" '- AC8: Given the skill text'
  ptr_line "works-on-its-own fixed defaults rule (AC36)" "$wspec" '- Commit/push only with the user'\''s permission; merge only, never rebase'
else
  echo "skipped: working-record checks (not shipped)"
fi

# --- rename to ordo: README, publisher, leak-check pointers (AC11, AC13, AC15, AC25) ---
eq "README title" "# ordo" "$(sed -n 1p "$readme")"
# old names are built from parts so that this file passes the personal-reference and old-name greps itself
old_name=$(printf 'ro%s' les); old_path="~/dev/claude-$old_name"; publisher=gfarkas-ep
eq "CHANGELOG has exactly one rename line" 1 "$(grep -cF "renamed from $old_name in 0.12.0" "$changelog")"
eq "README does not repeat the rename line" 0 "$(grep -cF "renamed from $old_name in 0.12.0" "$readme")"
if grep -qF "$old_path" "$readme"; then bad "README names the old repo path (AC11)"; else ok; fi
has "README install: marketplace add (publish AC4, AC5)" 'claude plugin marketplace add gfarkas-ep/ordo' "$readme"
has "SECURITY advisory link (publish AC5)" 'https://github.com/gfarkas-ep/ordo/security/advisories/new' SECURITY.md
eq "plugin.json repository (publish AC6)" 'https://github.com/gfarkas-ep/ordo' "$(jq -r .repository "$plugin" 2>/dev/null)"
eq "CHANGELOG 0.10.0 lacks the lighter-defaults pointer sentence (publish AC14)" 0 "$(grep -cF 'carry pointers to `docs/specs/2026-11-16-lighter-defaults.md` where it supersedes them' "$changelog")"
has "README install: plugin install" 'claude plugin install ordo@ordo-marketplace' "$readme"
has "README update line: marketplace update then plugin update" 'Updates: `claude plugin marketplace update ordo-marketplace`, then `claude plugin update ordo@ordo-marketplace`.' "$readme"
has "README auto-update is off by default" 'Auto-update is off by default for this marketplace' "$readme"
has "README auto-update how to turn on" 'turn it on in `/plugin` under Marketplaces (select ordo-marketplace, turn on auto-update)' "$readme"
has "README manual plugin update" 'claude plugin update ordo@ordo-marketplace' "$readme"
# publish T5c: pull request policy and publishing steps (AC22, AC23, AC32, AC21 backup part)
noreply='359341123+gfarkas-ep''@users.noreply.github.com'   # the only address CONTRIBUTING may hold; built in two parts
prsec=$(awk '/^## Pull requests/{p=1;next} /^## /{p=0} p' "$contrib")
prhas() { case "$prsec" in *"$2"*) ok;; *) bad "CONTRIBUTING pull requests: $1 ('$2' missing in that section)";; esac; }
prhas "applied by the maintainer in the source repo, shipped in the next release (AC22)" 'Accepted pull requests are applied by the maintainer in the source repository and shipped in the next release with credit'
prhas "Co-Authored-By with the noreply address, never a private one (AC22)" 'a `Co-Authored-By:` line with the contributor'\''s GitHub noreply address, never a private one'
prhas "pull request closed with a link to the release commit (AC22)" 'The pull request is then closed with a link to that release commit'
prhas "nothing merged on GitHub (AC22)" 'nothing is merged on GitHub'
prhas "GitHub-only changes undone by the next export (AC23)" 'anything changed only on GitHub (an automated update, a web edit) is undone by the next export'
# publish T7: CONTRIBUTING has no Publishing section (the publishing steps are not part of the shipped docs)
eq "CONTRIBUTING has no Publishing section (publish AC32)" 0 "$(grep -c '^## Publishing' "$contrib")"
for t in test-ci-workflow; do has "CONTRIBUTING test list: $t" "scripts/$t.sh" "$contrib"; done
grep -qF 'until the repository exists' "$contrib" && bad "CONTRIBUTING still says 'until the repository exists'" || ok
grep -qF 'your private list' "$contrib" && bad "CONTRIBUTING says 'your private list' (maintainer wording)" || ok
eq "CONTRIBUTING says 'Pull requests are welcome' once" 1 "$(grep -oF 'Pull requests are welcome' "$contrib" | wc -l | tr -d ' ')"
has "CHANGELOG 0.12.0 note names the breaking rename" '0.12.0 is a breaking rename' "$changelog"
eq "marketplace owner name" "$publisher" "$(jq -r .owner.name "$market" 2>/dev/null)"
eq "plugin author name" "$publisher" "$(jq -r .author.name "$plugin" 2>/dev/null)"
has "LICENSE copyright holder" "Copyright (c) 2026 $publisher" LICENSE

# --- Legal and credits (ROADMAP item 1) ---
has "LICENSE is MIT" 'MIT License' LICENSE
has "LICENSE grants permission" 'Permission is hereby granted, free of charge' LICENSE
has "LICENSE copyright line" 'Copyright (c) 2026 ' LICENSE
for f in LICENSE "$readme"; do
  grep -qiE 'all rights reserved|proprietary' "$f" && bad "'All rights reserved' or 'proprietary' left in $f" || ok
done
has "README Credits heading" '## Credits' "$readme"
has "README credits mattpocock" 'mattpocock/skills' "$readme"
has "README credits karpathy skills" 'forrestchang/andrej-karpathy-skills' "$readme"
[ -f claude-md/LICENSE-andrej-karpathy-skills ] && ok || bad "claude-md/LICENSE-andrej-karpathy-skills missing"
has "karpathy licence is MIT" 'Permission is hereby granted, free of charge' claude-md/LICENSE-andrej-karpathy-skills
has "karpathy licence copyright" 'Copyright (c) the andrej-karpathy-skills authors' claude-md/LICENSE-andrej-karpathy-skills

has "README Licence heading" '## Licence' "$readme"
has "README says adapted for karpathy sections" 'are adapted from its `CLAUDE.md`' "$readme"
eq "plugin.json license" MIT "$(jq -r .license "$plugin" 2>/dev/null)"
for sk in tdd diagnose grill; do
  l=plugins/ordo/skills/$sk/LICENSE
  has "$sk LICENSE copyright" 'Copyright (c) 2026 Matt Pocock' "$l"
  has "$sk LICENSE permission" 'Permission is hereby granted, free of charge' "$l"
  has "$sk Adapted from line" 'Adapted from mattpocock/skills' plugins/ordo/skills/$sk/SKILL.md
done

# --- Plans in the repo (AC9, AC10, AC12) ---
cp_skill=plugins/ordo/skills/consult-panel/SKILL.md
goal_skill=plugins/ordo/skills/goal/SKILL.md
has "consult-panel saves plans in docs/plans/" 'docs/plans/' "$cp_skill"
has "consult-panel plan has Progress section" 'Progress' "$cp_skill"
has "consult-panel plan has Changes after the panel" 'Changes after the panel' "$cp_skill"
has "goal skill has Plan: line rule" '`Plan: docs/plans/' "$goal_skill"
[ -f "$cp_skill" ] && ! grep -qi 'scratchpad' "$cp_skill" && ok || bad "consult-panel missing or still mentions the scratchpad"
has "consult-panel step 1 save rule" 'Save it in the project as `docs/plans/<YYYY-MM-DD>-<slug>.md`' "$cp_skill"
case "$(grep -F '`ordo:consult-panel`' "$readme" | head -1)" in *'docs/plans/<date>-<slug>.md'*) ok;; *) bad "README consult-panel table row lacks the plan path";; esac
has "goal: Progress line after each task" 'After each task, add its Progress line to the plan' "$goal_skill"
has "goal: plan files created without asking" 'created without asking, like specs' "$goal_skill"
has "consult-panel: plan file exists whenever the panel runs" 'A plan file exists whenever this skill runs, at any tier; work that never runs consult-panel has none.' "$cp_skill"
has "goal: plan file exists whenever consult-panel runs" 'A plan file exists whenever consult-panel runs, at any tier; work that never runs consult-panel has none.' "$goal_skill"
has "consult-panel step 2 seat pointer" 'Point them at the plan file path in `docs/plans/`' "$cp_skill"
has "consult-panel step 4 ADR both rule" 'record it as an ADR: both, not either.' "$cp_skill"
has "consult-panel step 1 Plan: paragraph" 'Then set the `Plan: docs/plans/<file>` line in the `## Current goal` section of `ROADMAP.md`, right after the goal sentence' "$cp_skill"
has "consult-panel step 4 ready-to-commit sentence" 'list as ready to commit the plan file, the `ROADMAP.md` change and any ADRs' "$cp_skill"
step4=$(sed -n '/^## 4\./,$p' "$cp_skill")
case "$step4" in *'not approved'*) ok;; *) bad "consult-panel step 4 lacks the rejected-plan rule";; esac
has "goal Files lists docs/plans/" 'docs/plans/' "$goal_skill"
has "README plan path" 'docs/plans/<date>-<slug>.md' "$readme"
has "README Plan: line" '`Plan:` line' "$readme"

# --- Judging requirements rule ---
has "goal: Judging requirements section" "Think through every aspect, then judge each against the current goal. A requirement, option or question you add that the goal does not need is made up: drop it, and do not ask about it. The user's own requests and reviewers' findings are not yours to drop: they follow the side-request and review-round rules. A genuine issue, one that affects the goal, its done-criteria or a keep category, goes to the front, plainly, even if nobody asked." "$goal_skill"
has "ba: write only what the goal needs" 'Write only criteria and questions the request or goal needs; raise a genuine gap first, even if unasked; never invent a requirement to be thorough.' plugins/ordo/agents/ba.md
has "README judging requirements rule" 'Judging requirements: drop what you add that the goal does not need (the user'\''s requests and reviewers'\'' findings follow their own rules), raise a genuine issue first, even if nobody asked.' "$readme"
eq "goal: Judging requirements right before Questions to the user" "## Judging requirements" "$(grep '^## ' "$goal_skill" | grep -B1 '^## Questions to the user' | head -1)"
has "goal description mentions judging requirements" 'a requirement to judge' "$goal_skill"

# --- lighter-defaults T2: one source for the "Findings and rounds" block (AC29, AC31-AC33, A8) ---
src=shared/findings-and-rounds.md
begin='<!-- BEGIN findings-and-rounds (generated by scripts/sync-rules-block.sh from shared/findings-and-rounds.md; edit the source) -->'
end='<!-- END findings-and-rounds -->'
block_of() { awk -v b="$begin" -v e="$end" '$0==e{p=0} p{print} $0==b{p=1}' "$1"; }
# check_copy <agent file> <source>: prints "<file>: reason" and returns 1 when the copy is not exactly the source
check_copy() {
  local f=$1 s=$2 nb ne got
  nb=$(grep -cxF -- "$begin" "$f"); ne=$(grep -cxF -- "$end" "$f")
  if [ "$nb" != 1 ] || [ "$ne" != 1 ]; then echo "$f: expected exactly one marker pair, found $nb begin and $ne end"; return 1; fi
  got=$(block_of "$f")
  if [ -z "$got" ]; then echo "$f: block between markers is empty"; return 1; fi
  if ! block_of "$f" | cmp -s - "$s"; then echo "$f: block differs from $s"; return 1; fi
}
[ -s "$src" ] && ok || bad "$src missing or empty"
for a in code-reviewer qa po; do
  msg=$(check_copy "plugins/ordo/agents/$a.md" "$src") && ok || bad "rules block copy: $msg"
done
# negative test: a copy with one character changed, and a copy with a marker missing, must fail and name the file
tmpd=$(mktemp -d)
cp plugins/ordo/agents/qa.md "$tmpd/changed.md"; cp plugins/ordo/agents/qa.md "$tmpd/nomarker.md"
sed '/^- Tag every finding/s/exactly one/exactly onE/' "$tmpd/changed.md" > "$tmpd/c2" && mv "$tmpd/c2" "$tmpd/changed.md"
grep -vxF -- "$end" "$tmpd/nomarker.md" > "$tmpd/n2"; mv "$tmpd/n2" "$tmpd/nomarker.md"
cp plugins/ordo/agents/qa.md "$tmpd/blank.md"
awk -v e="$end" '$0==e{print ""} {print}' "$tmpd/blank.md" > "$tmpd/b2" && mv "$tmpd/b2" "$tmpd/blank.md"
for n in changed nomarker blank; do
  if msg=$(check_copy "$tmpd/$n.md" "$src"); then bad "block check passes a copy that is $n"; else
    case "$n:$msg" in "changed:$tmpd/changed.md: block differs"*|"nomarker:$tmpd/nomarker.md: expected exactly one marker pair"*|"blank:$tmpd/blank.md: block differs"*) ok;; *) bad "block check failure does not name the file for the right reason ($n): $msg";; esac
  fi
done
# sync script: END before BEGIN must be refused and leave the file byte-identical
cp plugins/ordo/agents/qa.md "$tmpd/swapped.md"
awk -v b="$begin" -v e="$end" '$0==b{hb=$0; next} $0==e{print; print hb; next} {print}' "$tmpd/swapped.md" > "$tmpd/s2" && mv "$tmpd/s2" "$tmpd/swapped.md"
cp "$tmpd/swapped.md" "$tmpd/swapped.orig"
if bash scripts/sync-rules-block.sh "$tmpd/swapped.md" >/dev/null 2>&1; then bad "sync accepts END before BEGIN"; else ok; fi
cmp -s "$tmpd/swapped.md" "$tmpd/swapped.orig" && ok || bad "sync changed a file with END before BEGIN"
rm -rf "$tmpd"
eq "agent file count stays six" 6 "$agents_files"
eq "skill dir count stays eleven" 11 "$skills_dirs"
has "block: one re-review wording" 'In a re-check of a fix round, a NOT RESOLVED or DISPUTED (kept) previous finding' "$src"
grep -qF '(Mode B)' "$src" && bad "$src still says (Mode B) in the verdict sentence" || ok
has "block: re-check answers" 'each previous finding gets one of RESOLVED / PARTIAL / NOT RESOLVED / DISPUTED (evidence given)' "$src"
has "block: DISPUTED definition" 'DISPUTED means the main session (in the re-check brief) answered the finding with evidence that it is wrong' "$src"
has "block: DISPUTED (withdrawn) closes" 'Answer DISPUTED (withdrawn) when you withdraw the finding: it closes.' "$src"
has "block: DISPUTED (kept) blocks like NOT RESOLVED" 'Answer DISPUTED (kept) when you keep it with counter-evidence: it stays open, blocks like NOT RESOLVED' "$src"
has "block: kept dispute goes to the user" 'and goes to the user, who answers it.' "$src"
has "code-reviewer Mode B lists four answers" 'For each finding: RESOLVED / PARTIAL / NOT RESOLVED / DISPUTED (withdrawn) / DISPUTED (kept), with evidence.' plugins/ordo/agents/code-reviewer.md
has "code-reviewer Output lists four answers" '## Previous findings (mode B) — finding — RESOLVED/PARTIAL/NOT RESOLVED/DISPUTED (withdrawn)/DISPUTED (kept) — evidence' plugins/ordo/agents/code-reviewer.md
has "qa output previous-findings line" '## Previous findings (re-check) — finding — RESOLVED/PARTIAL/NOT RESOLVED/DISPUTED (withdrawn)/DISPUTED (kept) — evidence (or none)' plugins/ordo/agents/qa.md
has "po Mode B output previous-findings line" '- <finding> — RESOLVED | PARTIAL | NOT RESOLVED | DISPUTED (withdrawn) | DISPUTED (kept) — evidence (or none)' plugins/ordo/agents/po.md

# --- lighter-defaults T3b: consult-panel, eval-plan, refine, diagnose (AC7, AC9-AC11, AC13, AC16, AC18, AC43); key and step on one line ---
# one exact note per step, checked inside the step's own section (a swapped note fails)
sec_has() { # name file section-heading-prefix string
  local sec; sec=$(awk -v h="$3" 'index($0,h)==1{p=1;next} /^## /{p=0} p' "$2")
  case "$sec" in *"$4"*) ok;; *) bad "$1: '$4' missing in section '$3' of $2";; esac
}
sec_has "consult-panel step 2: plan_review skips the three seats, plan saved, approval required, dev seat (AC13, AC16, AC43)" "$cp_skill" '## 2. ' 'Skipped when `ordo plan_review: off` (switch rule: `ordo:workflow`): dispatch no dev, qa or po seat; the plan file is still written and saved and the user'\''s approval is still required. The dev seat follows `plan_review` alone, never `ordo dev_helper_tier2`.'
sec_has "consult-panel step 3: plan_review off shows the plan, then step 4 (AC16)" "$cp_skill" '## 3. ' 'Skipped when `ordo plan_review: off`: show the user the plan'\''s goal, its task list and the plan file path, then go to step 4.'
has "consult-panel: Progress verdict reads review off for the tier's code_review switch" 'the verdict reads "review off" when that tier'\''s code review switch is off (`ordo code_review_tier1` or `ordo code_review_tier2`).' "$cp_skill"
[ "$(grep -cF 'under the project'\''s git rules (`ordo git_rules`: the user'\''s permission unless that switch is off)' "$cp_skill")" = 2 ] && ok || bad "consult-panel: the two commit lines do not point to the git_rules switch (AC7)"
grep -qF 'Commit nothing without' "$cp_skill" && bad "consult-panel still states a fixed commit rule (AC7)" || ok
grep -qF 'commit nothing without' "$cp_skill" && bad "consult-panel still states a fixed commit rule (AC7)" || ok
ep=plugins/ordo/skills/eval-plan/SKILL.md
has "eval-plan: on-case budget line unchanged (AC11)" '- **Budget**: cost and wall time.' "$ep"
has "eval-plan: on-case derivation unchanged (AC11)" 'Example: `(0.12 + 0.45) x 3 runs = $1.71`.' "$ep"
has "eval-plan: on-case stop rule unchanged (AC11)" '- **Stop rule**: when to abort (spend or time passed, a failure count reached) and what counts as a failure (`passed` false, an error, a timeout).' "$ep"
has "eval-plan: on-case compare line unchanged (AC11)" 'one line each: cases run (against the list), pass rate, cost, duration, stop rule triggered or not.' "$ep"
sec_has "eval-plan before the run: eval_budget off plan (AC9, AC43)" "$ep" '## Before the run' '   - **With `ordo eval_budget: off`** (switch rule: `ordo:workflow`): write no cost figure and no spend clause in the stop rule. The Budget part is then the wall-time estimate from the last results JSON `durationSeconds` or marked "guess". Cases with runs per case, Expected pass rate, the "time passed" clause, the failure count and what counts as a failure stay. The plan is still saved, shown in full, and waits for the explicit yes (steps 2 to 4).'
sec_has "eval-plan after the run: eval_budget off comparison, no cost deviation (AC10)" "$ep" '## After the run' '   - With `ordo eval_budget: off`, the comparison covers cases run, pass rate, duration and stop rule triggered or not, and states no cost deviation.'
rf=plugins/ordo/skills/refine/SKILL.md
has "refine: po_acceptance_tier1 note at its step (AC18)" 'A Tier 1 refine run makes `ordo:po` acceptance at the end required (skipped when `ordo po_acceptance_tier1: off`; switch rule: `ordo:workflow`).' "$rf"
has "refine: commit line points to git_rules (AC7)" 'Committing it follows the project'\''s git rules (`ordo git_rules`: the user'\''s permission unless that switch is off).' "$rf"
has "diagnose: fix step notes the dev_helper switch for the tier" '(Tier 1+ fixes go to the `ordo:dev` agent with the test as the verify step; skipped when `ordo dev_helper_tier1` or `ordo dev_helper_tier2` is off for that tier: you write the fix yourself, test-first; switch rule: `ordo:workflow`)' plugins/ordo/skills/diagnose/SKILL.md
for f in eval-plan refine diagnose; do
  if grep -qE '(^| )(I|my|me)( |$)' "plugins/ordo/skills/$f/SKILL.md"; then bad "$f has I/my/me"; else ok; fi
done

# --- lighter-defaults T4: README switches, light-mode example, AC44 sentences, evals, older-spec pointers, release (AC22-AC24, AC34-AC37, AC44) ---
has "README switches section" '## Switches' "$readme"
swsec=$(awk '/^## Switches/{p=1;next} /^## /{p=0} p' "$readme")
for k in guard_hook git_rules eval_budget dev_helper_tier1 dev_helper_tier2 code_review_tier1 code_review_tier2 plan_review qa_check po_acceptance_tier1 po_acceptance_tier2 stall_watch; do
  row=$(printf '%s\n' "$swsec" | grep -F -- "| \`$k\` |" | head -1)
  case "$row" in *"| on |"*) ok;; *) bad "README switch table row for $k lacks the default 'on'";; esac
done
[ "$(printf '%s\n' "$swsec" | grep -cE '^\| `[a-z_0-9]+` \| on \|')" = 12 ] && ok || bad "README switch table does not hold exactly 12 keys with default on (AC23)"
swkeys=$(printf '%s\n' "$swsec" | grep -oE '^\| `[a-z_0-9]+`' | tr -d '| `' | tr '\n' ' ')
eq "README switch keys in AC23 order, then usage_log (AC39, AC42)" 'guard_hook git_rules eval_budget dev_helper_tier1 dev_helper_tier2 code_review_tier1 code_review_tier2 plan_review qa_check po_acceptance_tier1 po_acceptance_tier2 stall_watch usage_log ' "$swkeys"
has "README switch line form" 'in the form `ordo <key>: on` or `ordo <key>: off`' "$readme"
has "README switch precedence" 'The project'\''s `CLAUDE.md` beats `~/.claude/CLAUDE.md`; with no line the key is on.' "$readme"
has "README no switch for refine, diagnose, goal, session-start line (AC23)" 'Refine, diagnose, goal discipline and the session-start line itself have no switch.' "$readme"
has "README git_rules off leaves the guard on (AC8)" 'with only `git_rules` off, the Bash guard still denies `git rebase` and force push.' "$readme"
has "README whole plugin off with claude plugin disable (AC23)" 'The whole plugin is turned off with `claude plugin disable`.' "$readme"
has "README switched-off line at session start (AC44)" 'Switches that are off are named in one `ordo: switched off:` line at session start.' "$readme"
has "README guard switch: session can switch it off itself (AC44)" 'The session itself can switch the guard off: it writes `ordo guard_hook: off` into `CLAUDE.md`, then runs the blocked command. This is accepted, not blocked; the switch is meant for your choice.' "$readme"
has "README light mode line 1 (AC22)" 'ordo dev_helper_tier1: off' "$readme"
has "README light mode line 2 (AC22)" 'ordo code_review_tier1: off' "$readme"
has "README light mode sentence (AC22)" 'Copying these two lines into `CLAUDE.md` turns off the Tier 1 helper agent and Tier 1 code review and leaves Tier 2 untouched.' "$readme"
lm=$(grep -rlE 'light_mode' "$readme" plugins shared 2>/dev/null | tr '\n' ' ')
eq "no light_mode key in plugin text (AC22)" "" "$lm"
has "README switches name the exact files read (fix round)" 'in the `CLAUDE.md` in the session'\''s working directory or in your global `~/.claude/CLAUDE.md`. Only these two files are read: not `.claude/CLAUDE.md`, not `CLAUDE.local.md`, not parent directories.' "$readme"
has "README Safety hook: guard_hook turns the guard off, files read after a match (fix round)" 'The guard is turned off by `ordo guard_hook: off` (see Switches); its two `CLAUDE.md` files are read only after a command matches one of the four families.' "$readme"
has "README Known limits: subdirectory start, guard stays on (fix round)" '- With the working directory in a subdirectory, the project line is not found (only that directory'\''s `CLAUDE.md` is read) and the guard stays on (fails safe).' "$readme"
has "README Goal hook: apart from the switched-off line, only the workflow line (fix round)" 'Apart from the `ordo: switched off:` line (see Switches), it prints only the workflow line when there is no `ROADMAP.md`' "$readme"
grep -qF 'A `ordo: switched off:` line (see Switches) follows the workflow line whenever' "$readme" && bad "README Goal hook still has the trailing switched-off sentence (fix round)" || ok
has "round2 description says stronger-model rerun (fix round)" 'does not offer the stronger-model rerun that round 4 gets' plugins/ordo/evals/round2-history-auto-runs/prompt.md
grep -qi 'opus' plugins/ordo/evals/round2-history-auto-runs/prompt.md && bad "round2 prompt still names Opus in its description" || ok
has "CHANGELOG 0.10.0 note names switches" 'adds on/off switches' "$changelog"
has "round4-asks-user description does not name Opus: AC16 options" 'one of the three AC16 options (stronger-model rerun, change of approach, park)' plugins/ordo/evals/round4-asks-user/prompt.md
grep -qi 'opus' plugins/ordo/evals/round4-asks-user/prompt.md && bad "round4-asks-user prompt still names Opus in its description (AC35)" || ok
has "round4 grader offers-ac16-recommendation stays (AC35)" 'stronger model' plugins/ordo/evals/round4-asks-user/graders/offers-ac16-recommendation.md
has "round2 grader no-opus-offer rejects Fable and stronger/higher model (AC35)" '(?:Opus|Fable)\b|stronger model|higher model' plugins/ordo/evals/round2-history-auto-runs/graders/no-opus-offer.md

# watch-helpers T4: README stall_watch row, watch settings, description, limits (AC19, AC26)
has "README stall_watch row: turns off the watch, brief rules stay (AC26)" '| `stall_watch` | on | The watch and the progress reports for background helpers; the four brief rules stay |' "$readme"
has "README watch settings: check minutes (AC26)" '| `watch_check_minutes` | 5 |' "$readme"
has "README watch settings: report minutes (AC26)" '| `watch_report_minutes` | 10 |' "$readme"
has "README watch settings: check_by (AC26)" '| `watch_check_by` | script |' "$readme"
has "README watch settings line form (AC26)" 'Set a value with one line per key, in the form `ordo <key>: <value>`' "$readme"
has "README watch settings: project beats global, next level or default (AC26)" 'The project `CLAUDE.md` beats `~/.claude/CLAUDE.md`; a line with another value is ignored and the next level or the default applies.' "$readme"
has "README watch settings: 10 minutes or more runs in model mode" 'A check interval of 10 minutes or more runs in `model` mode (one model turn per check): a Monitor lasts at most 30 minutes.' "$readme"
has "README Watching helpers section" '## Watching helpers' "$readme"
has "README watching: script path" '`plugins/ordo/skills/workflow/stall-check.sh`' "$readme"
has "README watching: report every 10 minutes, stall at once" 'a progress report every 10 minutes by default, and a stall at once' "$readme"
has "README watching: foreground limit" 'A foreground helper cannot be watched; only your Esc stops it.' "$readme"

# --- item 8: GitHub-ready documentation (README structure, new files, templates) ---
has "README Quick start" '## Quick start' "$readme"
has "README Worked example" '## Worked example' "$readme"
has "README When not to use it" '## When not to use it' "$readme"
has "README Install and uninstall" '## Install and uninstall' "$readme"
has "README Uninstall" '### Uninstall' "$readme"
has "README uninstall command" 'claude plugin uninstall ordo@ordo-marketplace' "$readme"
has "README marketplace remove" 'claude plugin marketplace remove ordo-marketplace' "$readme"
has "README disable alternative" 'claude plugin disable ordo@ordo-marketplace' "$readme"
eq "README headings in AC2 order" "Quick start|Worked example|When not to use it|Install and uninstall|Switches|Safety hook" "$(grep -E '^## (Quick start|Worked example|When not to use it|Install and uninstall|Switches|Safety hook)$' "$readme" | sed 's/^## //' | paste -sd'|' -)"
n_quick=$(awk '/^## Quick start/{p=1;next} /^## /{p=0} p && /^[0-9]+\. /' "$readme" | wc -l | tr -d ' ')
[ "$n_quick" -ge 1 ] && [ "$n_quick" -le 5 ] && ok || bad "README Quick start has $n_quick numbered steps, not 1 to 5"
eq "README holds no repo placeholder (publish AC2)" 0 "$(grep -cF -- "$ph_repo" "$readme")"
grep -qF 'cat claude-md/CLAUDE.md >>' "$readme" && bad "README still appends claude-md/CLAUDE.md blindly" || ok
has "README worked example: marketplace plugin-dir" '--plugin-dir ~/.claude/plugins/marketplaces/ordo-marketplace/plugins/ordo' "$readme"
has "README Quick start names the session-start line" 'ordo: load the ordo:workflow skill' "$readme"
wex=$(awk '/^## Worked example/{p=1;next} /^## /{p=0} p' "$readme")
case "$wex" in *'USD 0.'*) ok;; *) bad "README Worked example lacks a USD figure";; esac
case "$wex" in *2026-11-18*) ok;; *) bad "README Worked example lacks its date";; esac
case "$wex" in *'not a promise'*) ok;; *) bad "README Worked example does not say one run, not a promise";; esac
for f in CONTRIBUTING.md SECURITY.md SUPPORT.md CHANGELOG.md .github/ISSUE_TEMPLATE/bug_report.yml .github/ISSUE_TEMPLATE/feature_request.yml; do
  [ -f "$f" ] && ok || bad "$f missing"
done
has "CONTRIBUTING: MIT" 'MIT licence' "$contrib"
has "CONTRIBUTING: no contributor agreement" 'There is no contributor agreement' "$contrib"
has "CONTRIBUTING: test-first" 'test-first' "$contrib"
has "CONTRIBUTING: may be rejected" 'may be rejected if it does not fit' "$contrib"
has "SECURITY: private vulnerability reporting" 'GitHub private vulnerability reporting' SECURITY.md
has "SECURITY: no public issue" 'Do not open a public issue' SECURITY.md
has "SUPPORT: issues only" 'GitHub issues only' SUPPORT.md
has "SUPPORT: no response time" 'No response time is promised' SUPPORT.md
for t in bug_report feature_request; do
  has "$t template front matter" 'name: ' ".github/ISSUE_TEMPLATE/$t.yml"
  has "$t template body" 'body:' ".github/ISSUE_TEMPLATE/$t.yml"
done
# issue templates must be valid YAML (GitHub silently drops a template that does not parse)
if command -v ruby >/dev/null 2>&1; then
  for y in .github/ISSUE_TEMPLATE/*.yml; do
    ruby -ryaml -e 'YAML.load_file(ARGV[0])' "$y" >/dev/null 2>&1 && ok || bad "$y is not valid YAML"
  done
else
  echo "note: ruby missing, YAML parse of issue templates skipped"
fi
for w in 'Plugin version' 'Claude Code version' 'Operating system' 'Steps to reproduce' 'Expected result' 'Actual result' 'ordo switches'; do has "bug template asks: $w" "$w" .github/ISSUE_TEMPLATE/bug_report.yml; done
for w in 'Problem' 'Proposed behaviour' 'README philosophy'; do has "feature template asks: $w" "$w" .github/ISSUE_TEMPLATE/feature_request.yml; done
# the e-mail pattern: whole addresses are extracted and compared; with allow=1 only the exact maintainer noreply address passes (publish AC22), and only CONTRIBUTING.md gets allow=1
email_hit() { # file allow(0|1)
  local found
  found=$(grep -oiE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[a-z]{2,}' "$1")
  [ "$2" = 1 ] && found=$(printf '%s\n' "$found" | grep -vxF -- "$noreply")
  [ -n "$found" ]
}
etmp=$(mktemp)
printf 'x `%s>` y\n' "$noreply" > "$etmp"; email_hit "$etmp" 1 && bad "e-mail check flags the exact noreply address in CONTRIBUTING" || ok
printf 'x %s. y\n' "$noreply" > "$etmp"; email_hit "$etmp" 1 && bad "e-mail check flags the exact noreply address before a full stop" || ok
printf 'x %s y\n' "$noreply" > "$etmp"; email_hit "$etmp" 0 && ok || bad "e-mail check lets the noreply address through outside CONTRIBUTING"
printf 'x 1%s y\n' "$noreply" > "$etmp"; email_hit "$etmp" 1 && ok || bad "e-mail check lets 1<noreply> through"
printf 'x jo.%s y\n' "$noreply" > "$etmp"; email_hit "$etmp" 1 && ok || bad "e-mail check lets jo.<noreply> through"
printf 'x %s.evil.org y\n' "$noreply" > "$etmp"; email_hit "$etmp" 1 && ok || bad "e-mail check lets <noreply>.evil.org through"
printf 'x 1+other@users.noreply.github.com y\n' > "$etmp"; email_hit "$etmp" 1 && ok || bad "e-mail check lets a different noreply address through"
printf 'x someone@example.com y\n' > "$etmp"; email_hit "$etmp" 1 && ok || bad "e-mail check lets a private address through"
printf 'x someone@EXAMPLE.COM y\n' > "$etmp"; email_hit "$etmp" 1 && ok || bad "e-mail check lets an upper-case domain through"
rm -f "$etmp"
for f in README.md CONTRIBUTING.md SECURITY.md SUPPORT.md CHANGELOG.md .github/ISSUE_TEMPLATE/*.yml .github/pull_request_template.md .github/workflows/*; do
  allow=0; [ "$f" = CONTRIBUTING.md ] && allow=1
  email_hit "$f" "$allow" && bad "e-mail pattern in $f" || ok
  grep -qiE 'all rights reserved|proprietary' "$f" && bad "'All rights reserved' or 'proprietary' in $f" || ok
done
# the repo placeholder lives only in working records, never in a shipped file (publish AC2)
if [ -e .git ]; then
  lit=$(git ls-files -z | xargs -0 grep -lF -- "$ph_repo" 2>/dev/null | grep -vE '^(docs/|ROADMAP\.md|LOW_PRIORITY\.md|LESSONS\.md)' | tr '\n' ' ')
  eq "owner/repo placeholder only in working records" "" "$lit"
else
  echo "skipped: placeholder allow-list check (not a git work tree)"
fi

# --- item 10: diagnostics and feedback docs (AC39-AC42) ---
ulrow=$(printf '%s\n' "$swsec" | grep -F -- '| `usage_log` |' | head -1)
case "$ulrow" in *"| off |"*) ok;; *) bad "README switch table row for usage_log lacks the default 'off' (AC39)";; esac
[ "$(printf '%s\n' "$swsec" | grep -cE '^\| `[a-z_0-9]+` \| off \|')" = 1 ] && ok || bad "README switch table: usage_log is not the only default-off key (AC39)"
has "README: default sentence names the exception (AC39)" 'All are on by default except `usage_log`, which is off by default.' "$readme"
grep -qF 'Each switch turns off one rule or review step. All are on by default. Set' "$readme" && bad "README still says 'All are on by default.' without the exception (AC39)" || ok
has "README: usage_log has no line means off (AC39)" 'With no line, `usage_log` is off.' "$readme"
has "README Usage log section (AC39)" '## Usage log and feedback' "$readme"
ulsec=$(awk '/^## Usage log and feedback/{p=1;next} /^## /{p=0} p' "$readme")
ulhas() { case "$ulsec" in *"$2"*) ok;; *) bad "README usage log: $1 ('$2' missing)";; esac; }
ulhas "path" '`~/.config/ordo/usage.jsonl`'
ulhas "off by default, opt-in line" '`ordo usage_log: on`'
ulhas "readable only by you, plain text" 'The file is created readable only by you. It is plain text, one JSON object per line.'
for k in start end skill script agent agent-start launch ask call guard; do ulhas "line kind $k" "| \`$k\` |"; done
for f in time kind name target result round version off session call agent verdict family via; do ulhas "field $f" "- \`$f\`:"; done
ulhas "session code: short one-way code, never the ID" 'a short one-way code made from the session ID; never the ID itself.'
ulhas "call code: one-way, never the command" 'a short one-way code made from the session ID, the tool name and the tool input; never the command or any input itself.'
ulhas "agent code: one-way, never the ID" 'a short one-way code made from the agent'\''s ID; never the ID itself.'
ulhas "no session ID: no session, no call" 'With no session ID in the payload the line has no `session` and no `call`.'
ulhas "result ok" '`ok` (the call finished)'
ulhas "result failed" '`failed` (it failed)'
ulhas "result aborted: ended as an abort by the process" '`aborted` (it ended as an abort by the process)'
ulhas "result denied: refused in auto mode" '`denied` (Claude Code refused it in auto mode)'
ulhas "run time is not a field" 'Run time is not a field: the summary works it out as the finish time minus the start time of the same agent code, in whole seconds.'
ulhas "round only on launch lines" 'on `launch` lines; absent when the brief has none'
ulhas "verdict: first line, handback agents may have none" 'an agent that reports through the SubagentHandback tool may leave none.'
ulhas "skills count only through the Skill tool" 'A skill counts only when it is loaded through the Skill tool'
ulhas "scripts by file name only, Bash or Monitor tool only" 'A plugin script (`stall-check`, `usage-report`) counts by its file name only, and only when the Bash tool runs it or the Monitor tool starts it'
ulhas "script counted only by absolute path as first word of a segment" '(its absolute path, resolving to a script file under the plugin'\''s `skills/<dir>/`, is the first word of a command segment, alone or behind `sh`, `bash`, `zsh`, `python` or `python3`; a relative path, an unexpanded variable or a `K=V` prefix is not counted; only the first line of the command is read)'
ulhas "script command text and arguments not written" 'Neither the command text nor the script arguments are written.'
ulhas "Monitor launch counts as a run, outcome not reported" 'A Monitor launch of an own script counts as a run when it starts; its outcome is not reported, because Claude Code sends no hook when a Monitor ends.'
ulhas "via field: monitor, on script lines" '- `via`: the word `monitor`, on a `script` line written for a Monitor launch; Bash runs have no `via`.'
ulhas "summary: started through Monitor" 'a script that was started through Monitor shows "started through Monitor M (outcome not reported)"'
has "CHANGELOG 0.13.0 names Monitor launches" 'A Monitor launch of an own script counts as a run when it starts' "$changelog"
ulhas "only own skills, agents and scripts, guard line the one exception" 'Only the plugin'\''s own skills, agents and scripts are logged, by their own names, with one exception: any Bash command that the guard would block writes a `guard` line (family and session code only), whether or not it runs an own script. A call to anything else writes nothing.'
ulhas "not allowed: asked, never ran, unanswered prompt" '"Not allowed" is a call that was asked for permission and never ran. It also counts a prompt left unanswered until the session ended.'
ulhas "cancelled: started, never asked, no outcome, killed session" '"Cancelled" is a call that started, was never asked about and never reported an outcome, so you stopped it or the session ended (a killed session counts as cancelled).'
ulhas "inferred numbers: rejected or unanswered prompt, cancelled" 'so the not-allowed count from a rejected or unanswered prompt and the cancelled count are inferred.'
ulhas "aborted is not cancelled" 'An abort by the process is `aborted`, never cancelled.'
ulhas "auto-mode denial: result denied" 'A denial in auto mode is reported: it is written with result `denied`.'
ulhas "auto-mode denial: its own count, never in not allowed" '"Not allowed" never counts an auto-mode denial; "denied (auto mode)" is its own count and means Claude Code in auto mode refused the call (you did not).'
ulhas "allowed then stopped counts as not allowed" 'looks like a rejected prompt, so it counts as not allowed, not as cancelled'
ulhas "background agent stopped: only started, never finished" 'a background agent you stopped after launch (that stop shows only this way)'
ulhas "auto-mode denial settles the earlier prompt" 'A denial settles the earlier prompt of the same call, so the call is counted once, as denied.'
ulhas "line kinds: script row names the Monitor tool and via" 'or one started through the Monitor tool was started, failed, was aborted or was denied | `name`, `result`, `version`, `off`, `session`, `call`; `via` on a Monitor launch |'
ulhas "summary numbers" 'runs, failed, aborted, asked, ran, not allowed, denied (auto mode) and cancelled (agents also started, never finished)'
ulhas "codes never printed" 'The codes are used to pair lines and are never printed.'
ulhas "never logged" 'Never logged: prompt text, agent output (apart from one verdict word), error text, the reason of a denial, permission suggestions, command text, script arguments, the interrupt flag itself (only the result `aborted` is written), code, file names (other than the name of an own script), paths, project names, the session ID, the agent ID, the tool input, and the names of skills, agents and scripts that are not the plugin'\''s own.'
ulhas "90-day cap" 'Lines older than 90 days are removed the next time a line is written, and the summary ignores them.'
ulhas "how to read" 'open it with any editor or `cat`, or say `show my usage`'
ulhas "how to clear" 'To clear it, ask the `ordo:feedback` skill in words (for example "clear my usage log")'
ulhas "how to turn off" 'To turn logging off, set the line `ordo usage_log: off`'
ulhas "no network" 'The hooks make no network call and spawn no process;'
ulhas "feedback: user-started only" '`/ordo:feedback` runs only when you start it'
ulhas "feedback: settings list with level, no path, logging on or off" 'adds the list of all 13 switches and the 7 value settings with their level (`project`, `global` or `default`; never a file path; whether or not `usage_log` is on)'
ulhas "feedback: full preview, explicit yes" 'prints the full text and sends nothing until you answer yes to that exact text'
ulhas "feedback: gh or paste" 'with `gh issue create` when `gh` is installed, otherwise it prints the text and the new-issue link for you to paste'
ulhas "feedback: repo address from plugin.json" 'The repository address is read from the `repository` field of `plugin.json` (`https://github.com/gfarkas-ep/ordo`); when that field is not set, nothing is sent and the text is only printed.'
ulhas "switched-off line unchanged" 'never named in the `ordo: switched off:` line'
for gone in '| `seconds` |' '`seconds`:' 'nothing is paired' 'from the duration the finished call reports' 'the call finished successfully' 'No field is dropped'; do
  case "$ulsec" in *"$gone"*) bad "README usage log still holds a claim the code does not back: $gone (AC39)";; *) ok;; esac
done
has "CHANGELOG 0.13.0 names the counts (AC41)" 'the usage summary counts runs, failed, aborted, not allowed, denied (auto mode) and cancelled' "$changelog"
has "CHANGELOG 0.13.0 names the settings list (AC41)" 'a list of all your settings and their level' "$changelog"
has "CHANGELOG 0.13.0 says nothing is sent automatically (AC41)" 'Nothing is sent automatically: the hooks make no network call.' "$changelog"
has "README Safety hook: still no file writes, no network (AC40)" 'standard library only, no file writes, no network)' "$readme"
has "README Goal hook: still read-only (AC40)" 'standard library only, read-only)' "$readme"
has "hooks.json description mentions the usage log (AC42)" 'usage log' plugins/ordo/hooks/hooks.json

# --- publish T4a: CODE_OF_CONDUCT.md and the pull request template (AC8, AC9); the contact address lives in CODE_OF_CONDUCT.md only ---
coc=CODE_OF_CONDUCT.md
contact='ordo.oss.project''@gmail.com'   # built in two parts so this file does not hold the address
eq "CoC title" "# Contributor Covenant Code of Conduct" "$(grep -m1 '^# ' "$coc" 2>/dev/null)"
has "CoC is Contributor Covenant 2.1" 'This Code of Conduct is adapted from the [Contributor Covenant][homepage], version 2.1,' "$coc"
has "CoC contact line" "may be reported to the community leaders responsible for enforcement at $contact. All complaints" "$coc"
grep -qF '[INSERT' "$coc" 2>/dev/null && bad "CoC still has an [INSERT placeholder" || ok
eq "CoC holds the contact address once" 1 "$(grep -cF -- "$contact" "$coc" 2>/dev/null)"
if [ -e .git ]; then
  eq "contact address in no tracked file but CODE_OF_CONDUCT.md (outside the working records)" "$coc" "$(git ls-files -z | xargs -0 grep -lF -- "$contact" 2>/dev/null | grep -vE '^(docs/|ROADMAP\.md|LOW_PRIORITY\.md|LESSONS\.md)' | tr '\n' ' ' | sed 's/ $//')"
else
  echo "skipped: contact address allow-list check (not a git work tree)"
fi
has "README points to the code of conduct" '`CODE_OF_CONDUCT.md`' "$readme"
has "CONTRIBUTING points to the code of conduct" '`CODE_OF_CONDUCT.md`' "$contrib"
prt=.github/pull_request_template.md
has "PR template asks what changed" 'What changed' "$prt"
has "PR template asks which tests ran" 'Which tests ran' "$prt"
has "PR template asks about CHANGELOG" 'CHANGELOG.md updated' "$prt"

echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
