#!/bin/bash
# Free tests for the base eval cases of agents and skills (self-improvement loop, AC28 regression round):
# no agent runs, no paid eval. Checks: case files and tags, scaffolds in a throwaway HOME, the real-home
# refusal, grader regexes on matching and non-matching samples (run with node: grader regexes are JavaScript).
set -uo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
ev="$root/plugins/ordo/evals"
tmp_root=${TMPDIR:-/tmp}; tmp_root=${tmp_root%/}
work=$(mktemp -d "$tmp_root/base-evals-test.XXXXXX")
trap '[ -n "${work:-}" ] && [ "${work#"$tmp_root"/}" != "$work" ] && rm -rf "$work"' EXIT

pass=0; fail=0
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "FAIL - $1"; }
has() { grep -qF -- "$2" "$3" 2>/dev/null && ok || bad "$1"; }
eq()  { [ "$2" = "$3" ] && ok || bad "$1 (want '$2', got '$3')"; }

cases=""
# case_basics <name> <tag> <scaffold: yes|no>: front matter, tag (batch), runs, graders, scaffold named
case_basics() {
  local c=$1
  cases="$cases $c"
  [ -f "$ev/$c/prompt.md" ] || { bad "$c: prompt.md missing"; return; }
  eq "$c: name" "name: $c" "$(sed -n 's/^\(name: .*\)$/\1/p' "$ev/$c/prompt.md")"
  eq "$c: tag" "$2" "$(sed -n 's/^tags: \[\(.*\)\]$/\1/p' "$ev/$c/prompt.md")"
  eq "$c: runs 3" "runs: 3" "$(sed -n 's/^\(runs: .*\)$/\1/p' "$ev/$c/prompt.md")"
  local n; n=$(find "$ev/$c/graders" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
  [ "$n" -ge 1 ] && ok || bad "$c: no graders"
  has "$c: case.yaml names scaffold.sh" "scaffold_script: scaffold.sh" "$ev/$c/case.yaml"
  # regexes are JavaScript: no inline flag groups, no Python-only anchors
  grep -rqE '(\(\?[A-Za-z])|(^|[^\\])(\\\\)*\\[AZz]' "$ev/$c/graders" 2>/dev/null && bad "$c: grader has an inline flag or a Python-only anchor" || ok
}

sandbox() { # name: fresh HOME and cwd under $work
  rm -rf "$work/$1"; mkdir -p "$work/$1/home/cwd"; echo "$work/$1/home"
}
run_scaffold() { # case home -> runs the scaffold with HOME=home in home/cwd
  (cd "$2/cwd" && HOME="$2" sh "$ev/$1/scaffold.sh" >"$2/out" 2>&1); echo $?
}
nothing_outside() { # case home: only cwd (and the captured output) in the throwaway home
  eq "$1: nothing outside the working directory" "cwd" "$(ls -A "$2" | grep -vx out)"
}

# rx <match|nomatch> <grader file> <key: input_match|pattern> <sample> [n]: the grader's regex (nth occurrence of the key,
# default first) and flags, in node
cat > "$work/rx.js" <<'JS'
const fs = require("fs");
const [file, key, sample, nth] = process.argv.slice(2);
const lines = fs.readFileSync(file, "utf8").split("\n");
const get = (k, n = 0) => {
  const l = lines.filter((x) => x.trimStart().startsWith(k + ":"))[n];
  if (!l) return "";
  let v = l.trimStart().slice(k.length + 1).trim();
  if (v.length > 1 && v[0] === "'" && v[v.length - 1] === "'") v = v.slice(1, -1).replace(/''/g, "'");
  return v;
};
console.log(new RegExp(get(key, Number(nth || 0)), get("flags")).test(sample) ? "match" : "nomatch");
JS
rx() {
  local got; got=$(node "$work/rx.js" "$2" "$3" "$4" "${5:-0}" 2>&1)
  [ "$got" = "$1" ] && ok || bad "$(basename "$(dirname "$(dirname "$2")")")/$(basename "$2"): want $1, got $got: $4"
}
llm() { # <name> <grader file>: an llm grader that names what does not decide
  [ -f "$2" ] && has "$1 is an llm grader" "type: llm" "$2" || bad "$1 grader missing"
  has "$1 says what does not decide the verdict" "not decide" "$2"
}

# ===== CASES =====

# --- qa-fails-unmet-criterion: ordo:qa on finished work with one unmet acceptance criterion ---
c=qa-fails-unmet-criterion; case_basics $c bash-skills
h=$(sandbox q1); eq "$c scaffold exit" 0 "$(run_scaffold $c "$h")"
for f in slug.js slug.test.js test.sh SPEC.md; do [ -f "$h/cwd/$f" ] && ok || bad "$c: $f missing"; done
eq "$c: the project's own tests pass" "ok 2 passed" "$(cd "$h/cwd" && sh test.sh 2>&1)"
eq "$c: AC3 is unmet by the code" "-hello-world-" "$(cd "$h/cwd" && node -e 'console.log(require("./slug").slugify("  Hello World  "))')"
has "$c: the spec has AC3" "AC3" "$h/cwd/SPEC.md"
nothing_outside $c "$h"
g="$ev/$c/graders/qa-dispatched.md"
rx match   "$g" input_match '{"subagent_type":"ordo:qa","description":"x","prompt":"y"}'
rx match   "$g" input_match '{"description":"x","subagent_type": "ordo:qa"}'
rx nomatch "$g" input_match '{"subagent_type":"ordo:dev","prompt":"ordo:qa"}'
g="$ev/$c/graders/verdict-fail.md"
rx match   "$g" pattern $'Intro\n## Verdict: FAIL\n## Coverage'
rx match   "$g" pattern '**Verdict: FAIL**'
rx match   "$g" pattern '## Verdict — FAIL'
rx nomatch "$g" pattern $'## Verdict\nFAIL'
rx nomatch "$g" pattern '## Verdict: PASS'
rx nomatch "$g" pattern '## Verdict: PASS | FAIL'
rx nomatch "$g" pattern 'The tests would FAIL if the code were wrong.'
g="$ev/$c/graders/report-format.md"
full=$'## Verdict: FAIL\n## Coverage\n- slugify -> test\n## Test quality\n- x\n## Checks\n- sh test.sh -> 2 passed\n## Issues\n- [unmet acceptance criterion] SPEC.md AC3\n## Previous findings (re-check)\nnone\n## To the low-priority list\nnone\n## Not verified\n- nothing'
rx match   "$g" pattern "$full"
rx match   "$g" pattern "$(printf '%s' "$full" | sed 's/^## \(.*\)$/**\1**/')"
for hd in 'Verdict' 'Coverage' 'Test quality' 'Checks' 'Issues' 'Not verified'; do
  rx nomatch "$g" pattern "$(printf '%s\n' "$full" | grep -v "^## $hd")"
done
rx nomatch "$g" pattern 'FAIL: AC3 is not met. Tests pass.'
g="$ev/$c/graders/ac3-named.md"
rx match   "$g" pattern '[unmet acceptance criterion] SPEC.md AC3: no test'
rx match   "$g" pattern 'AC 3 fails'
rx match   "$g" pattern 'it leaves a trailing hyphen'
rx match   "$g" pattern 'Leading whitespace is not dropped'
rx nomatch "$g" pattern 'AC1 and AC2 hold; AC30 is not in the spec.'
# unmet-in-issues and wrong-output-shown: the Issues section names AC3, and the wrong output appears anywhere in the
# report (an llm judge failed correct reports 3 of 6 times; one correct report showed the output under Checks only)
g="$ev/$c/graders/unmet-in-issues.md"
rx match   "$g" pattern $'## Verdict: FAIL\n\n## Issues\n- [unmet acceptance criterion] slug.js:2. AC3 is not implemented.\n\n## Not verified\n- none'
rx match   "$g" pattern $'**Issues**\n1. slug.js:2: the function never trims, so leading and trailing whitespace become hyphens.\n**Not verified**\n- none'
rx nomatch "$g" pattern $'## Coverage\n- AC3: untested, returns -hello-world-\n\n## Issues\nNone.\n\n## Not verified\n- AC3 edge cases'
rx nomatch "$g" pattern $'## Issues\n- slug.js:2 returns `-hello-world-` for padded input.\n\n## Not verified\n- none'
g="$ev/$c/graders/wrong-output-shown.md"
rx match   "$g" pattern $'## Checks\n- Direct call: `slugify("  Hello World  ")` returns `"-hello-world-"`.'
rx nomatch "$g" pattern $'## Issues\n- AC3 is not implemented; the output is hello-world with hyphens at both ends.'
[ ! -e "$ev/$c/graders/unmet-with-evidence.md" ] && ok || bad "$c: unmet-with-evidence.md should be gone (replaced by unmet-in-issues.md)"

# --- consult-panel-seats: ordo:consult-panel writes the plan, convenes the three seats, presents the synthesis ---
c=consult-panel-seats; case_basics $c dev-agent
h=$(sandbox p1); eq "$c scaffold exit" 0 "$(run_scaffold $c "$h")"
for f in report.js test.sh ROADMAP.md docs/specs/2026-11-23-report-json-flag.md; do [ -f "$h/cwd/$f" ] && ok || bad "$c: $f missing"; done
eq "$c: the project's own test passes" "ok 1 passed" "$(cd "$h/cwd" && sh test.sh 2>&1)"
has "$c: ROADMAP has a Current goal section" "## Current goal" "$h/cwd/ROADMAP.md"
has "$c: the spec has acceptance criteria" "AC1" "$h/cwd/docs/specs/2026-11-23-report-json-flag.md"
[ ! -e "$h/cwd/docs/plans" ] && ok || bad "$c: docs/plans exists before the run"
nothing_outside $c "$h"
g="$ev/$c/graders/consult-skill-loaded.md"
rx match   "$g" input_match '{"skill":"ordo:consult-panel"}'
rx match   "$g" input_match '{"skill": "consult-panel"}'
rx nomatch "$g" input_match '{"skill":"ordo:goal"}'
g="$ev/$c/graders/plan-file-written.md"
rx match   "$g" input_match '{"file_path":"/w/docs/plans/2026-11-23-report-json-flag.md","content":"# Plan\n"}'
rx match   "$g" input_match '{"content":"# Plan","file_path":"docs/plans/2026-11-23-json-flag.md"}'
rx nomatch "$g" input_match '{"file_path":"/w/docs/plan.md","content":"# Plan\n"}'
rx nomatch "$g" input_match '{"file_path":"/w/docs/plans/json-flag.md","content":"x"}'
rx nomatch "$g" input_match '{"file_path":"/w/ROADMAP.md","content":"see docs/plans/2026-11-23-json-flag.md"}'
for seat in dev qa po; do
  g="$ev/$c/graders/seat-$seat.md"
  rx match   "$g" input_match "{\"subagent_type\":\"ordo:$seat\",\"description\":\"x\",\"prompt\":\"y\"}"
  rx match   "$g" input_match "{\"description\":\"x\",\"subagent_type\": \"ordo:$seat\"}"
  rx nomatch "$g" input_match "{\"subagent_type\":\"ordo:ba\",\"prompt\":\"ordo:$seat\"}"
done
g="$ev/$c/graders/synthesis-headings.md"
full=$'## Plan — add a --json flag\n## Panel agrees on        — x\n## Panel disagrees on     — y\n## Changes I made to the plan — z\n## Open decisions for you — 1. q'
rx match   "$g" pattern "$full"
rx match   "$g" pattern "$(printf '%s' "$full" | sed 's/^## \(.*\) —/**\1** —/')"
rx match   "$g" pattern "$(printf '%s' "$full" | sed 's/^## /### /')"
for hd in 'Plan' 'Panel agrees on' 'Panel disagrees on' 'Changes I made to the plan' 'Open decisions for you'; do
  rx nomatch "$g" pattern "$(printf '%s\n' "$full" | grep -v "^## $hd")"
done
rx nomatch "$g" pattern 'The panel agrees on the plan and I made changes; open decisions follow.'
rx match   "$g" pattern "$(printf '%s' "$full" | sed 's/^## Plan — /## Plan: /')"
rx match   "$g" pattern "$(printf '%s' "$full" | sed 's/^## Plan — \(.*\)$/**Plan:** \1/')"
rx match   "$g" pattern "$(printf '%s' "$full" | sed 's/^## Plan — .*$/## Plan\nadd a --json flag/')"
rx nomatch "$g" pattern "$(printf '%s\n' "$full" | grep -v '^## Plan')"$'\nPlan file saved to docs/plans.'
c_turns=$(sed -n 's/^max_turns: //p' "$ev/$c/prompt.md"); [ "${c_turns:-0}" -ge 24 ] && ok || bad "$c: max_turns $c_turns is under 24"

# --- diagnose-before-code: ordo:diagnose is loaded before the code is read; one repro command; ranked hypotheses ---
c=diagnose-before-code; case_basics $c bash-skills
h=$(sandbox d1); eq "$c scaffold exit" 0 "$(run_scaffold $c "$h")"
for f in price.js price.test.js test.sh; do [ -f "$h/cwd/$f" ] && ok || bad "$c: $f missing"; done
eq "$c: the project's own test passes" "ok 1 passed" "$(cd "$h/cwd" && sh test.sh 2>&1)"
eq "$c: the reported bug is there (190, not 180)" "190" "$(cd "$h/cwd" && node -e 'console.log(require("./price").checkout([{price: 100, qty: 2}], 10))')"
nothing_outside $c "$h"
g="$ev/$c/graders/diagnose-skill-loaded.md"
rx match   "$g" input_match '{"skill":"ordo:diagnose"}'
rx match   "$g" input_match '{"skill": "diagnose"}'
rx nomatch "$g" input_match '{"skill":"ordo:tdd"}'
g="$ev/$c/graders/diagnose-before-source.md"
rx match   "$g" input_match '{"skill":"ordo:diagnose","args":""}' 0
rx nomatch "$g" input_match '{"skill":"ordo:tdd"}' 0
has "$c: before is a Skill, after is the first Bash call (the repro)" "tool: Bash" "$g"
# the after side is Bash, not a Read of the source: a run may build the repro without reading the source (seen in the
# first paid run), and tool_order fails when the after tool is never called
# tool_order uses the first call of each tool and fails when either is never called, so it cannot guard optional tools
g="$ev/$c/graders/no-shell-read-of-source.md"
has "$c: shell reads of the source: Bash max 0" "max: 0" "$g"
rx match   "$g" input_match '{"command":"cat price.js"}'
rx match   "$g" input_match '{"command":"head -20 /w/cwd/price.test.js"}'
rx match   "$g" input_match '{"command":"grep -n checkout *.js"}'
rx match   "$g" input_match '{"command":"sed -n 1,5p price.js"}'
rx nomatch "$g" input_match '{"command":"node -e \"console.log(require(\\\"./price\\\").checkout([{price:100,qty:2}],10))\""}'
rx nomatch "$g" input_match '{"command":"sh test.sh"}'
rx nomatch "$g" input_match '{"command":"node price.js"}'
[ ! -e "$ev/$c/graders/no-grep.md" ] && ok || bad "$c: no-grep.md should be gone (Grep is not allowed)"
case "$(grep '^allowed_tools:' "$ev/$c/prompt.md")" in *Grep*) bad "$c: Grep must not be in allowed_tools";; *) ok;; esac
llm "$c: repro-command" "$ev/$c/graders/repro-command.md"
llm "$c: hypotheses-ranked" "$ev/$c/graders/hypotheses-ranked.md"

# --- decision-writes-adr: ordo:decision writes docs/decisions/YYYY-MM-DD-<slug>.md in the template ---
c=decision-writes-adr; case_basics $c reader-write
h=$(sandbox a1); eq "$c scaffold exit" 0 "$(run_scaffold $c "$h")"
[ -f "$h/cwd/README.md" ] && ok || bad "$c: README.md missing"
[ ! -e "$h/cwd/docs" ] && ok || bad "$c: docs exists before the run (the skill creates it)"
nothing_outside $c "$h"
g="$ev/$c/graders/decision-skill-loaded.md"
rx match   "$g" input_match '{"skill":"ordo:decision"}'
rx match   "$g" input_match '{"skill": "decision"}'
rx nomatch "$g" input_match '{"skill":"ordo:diagnose"}'
g="$ev/$c/graders/adr-path.md"
rx match   "$g" input_match '{"file_path":"/w/docs/decisions/2026-11-23-notes-as-markdown-files.md","content":"x"}'
rx match   "$g" input_match '{"content":"x","file_path":"docs/decisions/2026-11-23-notes-storage.md"}'
rx nomatch "$g" input_match '{"file_path":"/w/docs/decisions/notes-storage.md","content":"x"}'
rx nomatch "$g" input_match '{"file_path":"/w/docs/adr/2026-11-23-notes-storage.md","content":"x"}'
rx nomatch "$g" input_match '{"file_path":"/w/README.md","content":"see docs/decisions/2026-11-23-notes-storage.md"}'
g="$ev/$c/graders/adr-headings.md"
body='# Notes are markdown files\n\n- **Date:** 2026-11-23\n- **Status:** Accepted\n\n## Context\nx\n\n## Decision\nx\n\n## Options considered\n- x\n\n## Consequences\n- Easier: x\n'
rx match   "$g" input_match '{"file_path":"/w/docs/decisions/2026-11-23-notes.md","content":"'"$body"'"}'
for hd in 'Context' 'Decision' 'Options considered' 'Consequences'; do
  rx nomatch "$g" input_match '{"file_path":"/w/docs/decisions/2026-11-23-notes.md","content":"'"${body//## $hd/## Other}"'"}'
done
rx nomatch "$g" input_match '{"file_path":"/w/NOTES.md","content":"'"$body"'"}'
g="$ev/$c/graders/adr-status.md"
rx match   "$g" input_match '{"file_path":"/w/docs/decisions/2026-11-23-notes.md","content":"'"$body"'"}'
rx match   "$g" input_match '{"file_path":"/w/docs/decisions/2026-11-23-notes.md","content":"# T\n\nStatus: Accepted\n"}'
rx match   "$g" input_match '{"file_path":"/w/docs/decisions/2026-11-23-notes.md","content":"# T\n\n**Status**: Accepted\n"}'
rx nomatch "$g" input_match '{"file_path":"/w/docs/decisions/2026-11-23-notes.md","content":"# T\n\n- **Date:** 2026-11-23\n"}'
rx nomatch "$g" input_match '{"file_path":"/w/docs/decisions/2026-11-23-notes.md","content":"# T\n\n- **Status:** Proposed\n"}'
rx nomatch "$g" input_match '{"file_path":"/w/NOTES.md","content":"- **Status:** Accepted\n"}'

# --- feedback-draft-not-sent: ordo:feedback shows the full draft, asks for the yes, sends nothing ---
c=feedback-draft-not-sent; case_basics $c dev-agent
h=$(sandbox f1); eq "$c scaffold exit" 0 "$(run_scaffold $c "$h")"
[ -f "$h/cwd/README.md" ] && ok || bad "$c: README.md missing"
eq "$c: no CLAUDE.md in the project (the settings helper reads it)" "" "$(ls -A "$h/cwd" | grep -x 'CLAUDE.md')"
# a token in the environment would let a broken skill file a real issue: the scaffold refuses
for tv in GH_TOKEN GITHUB_TOKEN GH_ENTERPRISE_TOKEN; do
  h=$(sandbox ft); out=$(cd "$h/cwd" && env "$tv=x" HOME="$h" sh "$ev/$c/scaffold.sh" 2>&1); rc=$?
  [ "$rc" -ne 0 ] && ok || bad "$c: scaffold ran with $tv set"
  case "$out" in *"refusing: $tv is set"*) ok ;; *) bad "$c: refusal message missing for $tv: $out" ;; esac
  [ -z "$(ls -A "$h/cwd")" ] && ok || bad "$c: wrote files with $tv set"
done
h=$(sandbox ft2); eq "$c: scaffold runs with the tokens set but empty" 0 "$(cd "$h/cwd" && GH_TOKEN= GITHUB_TOKEN= GH_ENTERPRISE_TOKEN= HOME="$h" sh "$ev/$c/scaffold.sh" >/dev/null 2>&1; echo $?)"
has "CONTRIBUTING names the token precondition for $c" "GH_TOKEN" "$root/CONTRIBUTING.md"
nothing_outside $c "$h"
rule="Leave source and test files exactly as you found them"
has "the rule quoted in $c prompt is in agents/qa.md" "$rule" "$ev/../agents/qa.md"
has "$c prompt answer 3 names the ordo rule" "$rule" "$ev/$c/prompt.md"
g="$ev/$c/graders/feedback-skill-loaded.md"
rx match   "$g" input_match '{"skill":"ordo:feedback"}'
rx match   "$g" input_match '{"skill": "feedback"}'
rx nomatch "$g" input_match '{"skill":"ordo:retro"}'
g="$ev/$c/graders/nothing-sent.md"
rx match   "$g" input_match '{"command":"gh issue create --repo a/b --title \"$(cat \"$dir/title\")\" --body-file \"$dir/body\""}'
rx match   "$g" input_match '{"command":"repo='"'"'a/b'"'"'; gh issue create --repo \"$repo\""}'
rx match   "$g" input_match '{"command":"gh api repos/a/b/issues -f title=x"}'
rx match   "$g" input_match '{"command":"curl -s -X POST https://api.github.com/repos/a/b/issues"}'
rx match   "$g" input_match '{"command":"wget https://example.com"}'
rx nomatch "$g" input_match '{"command":"command -v gh"}'
rx nomatch "$g" input_match '{"command":"uname -sr"}'
rx nomatch "$g" input_match '{"command":"dir='"'"'/tmp/x'"'"'; python3 /p/usage-report.py redact < \"$dir/draft\""}'
rx nomatch "$g" input_match '{"command":"python3 /p/usage-report.py settings"}'
g="$ev/$c/graders/no-hostname.md"
rx match   "$g" input_match '{"command":"hostname"}'
rx match   "$g" input_match '{"command":"uname -a"}'
rx match   "$g" input_match '{"command":"uname -n"}'
rx match   "$g" input_match '{"command":"uname -srn"}'
rx nomatch "$g" input_match '{"command":"uname -sr"}'
rx nomatch "$g" input_match '{"command":"claude --version"}'
g="$ev/$c/graders/no-private-bash.md"
rx match   "$g" input_match '{"command":"cat ~/.claude/projects/x/abc.jsonl"}'
rx match   "$g" input_match '{"command":"cat ~/.config/ordo/usage.jsonl"}'
rx match   "$g" input_match '{"command":"cat ~/.config/ordo/private-terms.txt"}'
rx match   "$g" input_match '{"command":"cat CLAUDE.md"}'
rx nomatch "$g" input_match '{"command":"python3 /p/usage-report.py settings"}'
rx nomatch "$g" input_match '{"command":"cat /p/.claude-plugin/plugin.json"}'
g="$ev/$c/graders/no-private-read.md"
rx match   "$g" input_match '{"file_path":"/Users/u/.claude/projects/x/abc.jsonl"}'
rx match   "$g" input_match '{"file_path":"/Users/u/.config/ordo/private-terms.txt"}'
rx match   "$g" input_match '{"file_path":"/w/CLAUDE.md"}'
rx nomatch "$g" input_match '{"file_path":"/Users/u/.claude/ordo/addons/feedback.md"}'
rx nomatch "$g" input_match '{"file_path":"/p/.claude-plugin/plugin.json"}'
g="$ev/$c/graders/draft-shown.md"
full=$'Title: the qa agent edited a test file\n### Plugin version\n0.15.0\n### Claude Code version\n2.1\n### Operating system\nDarwin 25.6.0\n### Steps to reproduce\nx\n### Expected result\ny\n### Actual result\nz\n### ordo switches and settings in use\nplan_review: on (default)'
rx match   "$g" pattern "$full"
rx match   "$g" pattern "$(printf '%s' "$full" | sed 's/^Title:/**Title:**/')"
rx match   "$g" pattern "$(printf '%s' "$full" | sed 's/^/> /')"
for hd in 'Title:' '### Plugin version' '### Claude Code version' '### Operating system' '### Steps to reproduce' '### Expected result' '### Actual result' '### ordo switches and settings in use'; do
  rx nomatch "$g" pattern "$(printf '%s\n' "$full" | grep -vF "$hd")"
done
rx nomatch "$g" pattern 'I drafted a report about the qa agent editing a test file. Shall I send it?'
g="$ev/$c/graders/asks-yes.md"
rx match   "$g" pattern 'Reply yes to send exactly this text.'
rx match   "$g" pattern 'Say "yes" and I will send it.'
rx match   "$g" pattern 'To send this, answer YES.'
rx nomatch "$g" pattern 'Here is the draft. Read every line.'
rx match   "$g" pattern 'Should I send exactly this text as a new issue on `owner/ordo`?'
rx match   "$g" pattern '**Do you want me to send exactly this text?** You can also ask me to edit it first.'
rx nomatch "$g" pattern 'I sent the issue. Do you want the link?'
rx nomatch "$g" pattern 'Send me your edits. Here is the draft.'
rx nomatch "$g" pattern 'I sent the issue. Yes, it is public.'

# --- grill-asks-one-round: ordo:grill asks one numbered round, each question with a recommendation, then waits ---
c=grill-asks-one-round; case_basics $c trigger
h=$(sandbox g1); eq "$c scaffold exit" 0 "$(run_scaffold $c "$h")"
[ -f "$h/cwd/README.md" ] && ok || bad "$c: README.md missing"
nothing_outside $c "$h"
g="$ev/$c/graders/grill-skill-loaded.md"
rx match   "$g" input_match '{"skill":"ordo:grill"}'
rx match   "$g" input_match '{"skill": "grill"}'
rx nomatch "$g" input_match '{"skill":"ordo:refine"}'
g="$ev/$c/graders/questions-numbered.md"
two=$'❓ **Q1** — **Audience**: who gets it?\n\n➡️ everyone\n\n❓ **Q2** — **Time**: when?\n\n➡️ 8am'
rx match   "$g" pattern "$two"
rx match   "$g" pattern $'❓ Q1: who?\n➡ all\n❓ Q2: when?\n➡ 8am\n❓ Q3: how?\n➡ mail'
rx nomatch "$g" pattern $'❓ **Q1** — **Audience**: who gets it?\n\n➡️ everyone'
rx nomatch "$g" pattern $'1. Who gets it?\n2. When?'
rx nomatch "$g" pattern $'Q1: who?\nQ2: when?'
g="$ev/$c/graders/each-has-recommendation.md"
rx nomatch "$g" pattern "$two"
rx nomatch "$g" pattern "$two"$'\n\nWaiting for your answers.'
rx match   "$g" pattern $'❓ **Q1** — **Audience**: who gets it?\n\n❓ **Q2** — **Time**: when?\n\n➡️ 8am'
rx match   "$g" pattern $'❓ **Q1** — **Audience**: who gets it?\n\n➡️ everyone\n\n❓ **Q2** — **Time**: when?'
rx match   "$g" pattern $'❓ **Q1** — **Audience**: who gets it?\n\n➡️ everyone\n\n❓ **Q2** — **Time**: when?\n\nWaiting for your answers.'
rx nomatch "$g" pattern "$two"$'\n\n❓ Anything to add before I recompute?'
rx nomatch "$g" pattern "$two"$'\n\nWaiting for your answers ❓'
g="$ev/$c/graders/no-second-round.md"
rx match   "$g" pattern "$two"$'\n\nRound 2\n\n❓ **Q1** — **Format**: html?'
rx nomatch "$g" pattern "$two"
rx nomatch "$g" pattern "$two"$'\n\n❓ **Q3** — **Format**: html?\n\n➡️ yes'
llm "$c: waits-for-answers" "$ev/$c/graders/waits-for-answers.md"
# no-write / no-edit could never fail here (the batch grants neither tool): not part of the case
for f in no-write no-edit; do [ ! -e "$ev/$c/graders/$f.md" ] && ok || bad "$c: $f grader can never fail, drop it"; done
grep -q 'Write or Edit' "$ev/$c/prompt.md" && bad "$c: description still claims no Write or Edit" || ok

# --- the real-home refusal: HOME is the account's real home (simulated with a PATH stub) ----
# A stub `id` makes the "real" account `nobody`, whose home is not writable, so a broken guard cannot damage anything.
nb=$(eval echo "~nobody"); nbp=$(cd "$nb" 2>/dev/null && pwd -P)
if [ -n "$nbp" ] && [ ! -w "$nbp" ]; then
  mkdir -p "$work/stub"; printf '#!/bin/sh\necho nobody\n' > "$work/stub/id"; chmod +x "$work/stub/id"
  ln -s "$nbp" "$work/homelink"
  for c in $cases; do
    for hh in "$nbp" "$work/homelink"; do
      mkdir -p "$work/guard/cwd"; rm -rf "$work/guard/cwd/"* "$work/guard/cwd/".[!.]* 2>/dev/null
      out=$(cd "$work/guard/cwd" && PATH="$work/stub:$PATH" HOME="$hh" sh "$ev/$c/scaffold.sh" 2>&1); rc=$?
      [ "$rc" -ne 0 ] && ok || bad "$c: scaffold ran with HOME=$hh (real home)"
      case "$out" in *"refusing: HOME is the real home"*) ok ;; *) bad "$c: refusal message missing for HOME=$hh: $out" ;; esac
      [ -z "$(ls -A "$work/guard/cwd")" ] && ok || bad "$c: wrote files before refusing"
    done
  done
else
  echo "skip - real-home refusal: cannot use the nobody account's home on this host"
fi

echo "test-base-evals: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
