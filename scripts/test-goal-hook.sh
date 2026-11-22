#!/bin/bash
# Tests for plugins/ordo/hooks/goal_context.py (workflow line always first, then the goal block). Free: fixture dirs + stdin only, no network, no Claude run.
# Seam: hook stdin + ROADMAP.md in a dir -> stdout, exit code, stderr. Set GOAL=<path> to test another script.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
goal=${GOAL:-$root/plugins/ordo/hooks/goal_context.py}
tmp_root=${TMPDIR:-/tmp}
tmp_root=${tmp_root%/}
work=$(mktemp -d "$tmp_root/goal-test.XXXXXX")
cleanup() {
  if [ -n "${work:-}" ] && [ -d "$work" ] && [ "${work#"$tmp_root"/}" != "$work" ]; then
    rm -r "$work"
  fi
}
trap cleanup EXIT

# fake home: the real ~/.claude/CLAUDE.md must never affect a sample
export HOME="$work/home"
mkdir -p "$HOME/.claude"
GLOBAL="$HOME/.claude/CLAUDE.md"

command -v jq >/dev/null || { echo "jq is required" >&2; exit 2; }
command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 2; }

fails=0
pass() { echo "ok   - $1"; }
fail() { echo "FAIL - $1"; fails=$((fails + 1)); }

W='ordo: load the ordo:workflow skill before your next reply (tiers, agents, skills).'
H='ordo: current goal (from ROADMAP.md). Load the ordo:goal skill before your next reply.'
T='…(truncated, see ROADMAP.md)'

# run_hook <run-dir> <stdin-text>: runs the hook with cwd=<run-dir>; sets out, err, rc
run_hook() {
  out=$(cd "$1" && printf '%s' "$2" | python3 "$goal" 2>"$work/err") && rc=0 || rc=$?
  err=$(cat "$work/err")
}

# check <name> <dir> <stdin> <expected-stdout>
check() {
  local name=$1 dir=$2 stdin=$3 want=$4
  run_hook "$work" "$stdin"
  if [ "$rc" = 0 ] && [ -z "$err" ] && [ "$out" = "$want" ]; then
    pass "$name"
  else
    fail "$name (rc=$rc err=[$err])"
    printf '  want: [%s]\n  got:  [%s]\n' "$want" "$out"
  fi
}

# fixture <name>: fresh dir $work/<name>; prints its path
fixture() { mkdir -p "$work/$1"; printf '%s' "$work/$1"; }
json_cwd() { jq -nc --arg c "$1" '{cwd: $c}'; }

d=$(fixture present)
printf '# Roadmap\n\n## Current goal\n\nShip 0.8.0.\nSecond line.\n\n## Later\nnope\n' > "$d/ROADMAP.md"
check "section present" "$d" "$(json_cwd "$d")" "$W
$H
Ship 0.8.0.
Second line."

GOALMD='# Roadmap\n\n## Current goal\n\nShip 0.8.0.\nSecond line.\n\n## Later\nnope\n'
GOALOUT="$H
Ship 0.8.0.
Second line."

d=$(fixture guardoff)
printf "$GOALMD" > "$d/ROADMAP.md"
printf 'ordo guard_hook: off\n' > "$d/CLAUDE.md"
check "ordo guard_hook: off in project CLAUDE.md is named in the switched-off line (AC6, AC38)" "$d" "$(json_cwd "$d")" "$W
ordo: switched off: guard_hook (project CLAUDE.md)
$GOALOUT"

# AC4: all 12 switch keys: `ordo <key>: off` is named, the old plugin prefix (built in parts) is ignored
OLDP=ro; OLDP+=les
for key in guard_hook git_rules eval_budget dev_helper_tier1 dev_helper_tier2 code_review_tier1 code_review_tier2 plan_review qa_check po_acceptance_tier1 po_acceptance_tier2 stall_watch; do
  d=$(fixture "swkey_$key")
  printf "$GOALMD" > "$d/ROADMAP.md"
  printf 'ordo %s: off\n' "$key" > "$d/CLAUDE.md"
  check "ordo $key: off is named in the switched-off line" "$d" "$(json_cwd "$d")" "$W
ordo: switched off: $key (project CLAUDE.md)
$GOALOUT"
  d=$(fixture "swold_$key")
  printf "$GOALMD" > "$d/ROADMAP.md"
  printf '%s %s: off\n' "$OLDP" "$key" > "$d/CLAUDE.md"
  check "old prefix $key: off is ignored" "$d" "$(json_cwd "$d")" "$W
$GOALOUT"
done

d=$(fixture swcontrol)
printf "$GOALMD" > "$d/ROADMAP.md"
printf 'ordo guard_hook: on\nsome prose\n' > "$d/CLAUDE.md"
check "control: only an on line, output unchanged (AC39)" "$d" "$(json_cwd "$d")" "$W
$GOALOUT"

d=$(fixture swglobal)
printf "$GOALMD" > "$d/ROADMAP.md"
printf 'ordo plan_review: off\n' > "$GLOBAL"
check "global switch off is named with ~/.claude/CLAUDE.md" "$d" "$(json_cwd "$d")" "$W
ordo: switched off: plan_review (~/.claude/CLAUDE.md)
$GOALOUT"

printf 'ordo plan_review: off\n' > "$GLOBAL"
d=$(fixture swprojon)
printf "$GOALMD" > "$d/ROADMAP.md"
printf 'ordo plan_review: on\n' > "$d/CLAUDE.md"
check "project on beats global off: no line" "$d" "$(json_cwd "$d")" "$W
$GOALOUT"

printf 'ordo qa_check: off\nordo eval_budget: off\n' > "$GLOBAL"
d=$(fixture swmulti)
printf "$GOALMD" > "$d/ROADMAP.md"
printf 'ordo code_review_tier1: off\nordo guard_hook: off\nordo qa_check: on\n- ordo git_rules: off\nordo stall_watch: off\nordo po_acceptance_tier2: off\n' > "$d/CLAUDE.md"
check "several keys in AC23 order, mixed project and global" "$d" "$(json_cwd "$d")" "$W
ordo: switched off: guard_hook (project CLAUDE.md), eval_budget (~/.claude/CLAUDE.md), code_review_tier1 (project CLAUDE.md), po_acceptance_tier2 (project CLAUDE.md), stall_watch (project CLAUDE.md)
$GOALOUT"
rm -f "$GLOBAL"

d=$(fixture swstall)
printf "$GOALMD" > "$d/ROADMAP.md"
printf 'ordo stall_watch: off\n' > "$d/CLAUDE.md"
check "ordo stall_watch: off in project CLAUDE.md is named in the switched-off line (AC25)" "$d" "$(json_cwd "$d")" "$W
ordo: switched off: stall_watch (project CLAUDE.md)
$GOALOUT"

d=$(fixture swstallglobal)
printf "$GOALMD" > "$d/ROADMAP.md"
printf 'ordo stall_watch: off\n' > "$GLOBAL"
check "global stall_watch off is named with ~/.claude/CLAUDE.md" "$d" "$(json_cwd "$d")" "$W
ordo: switched off: stall_watch (~/.claude/CLAUDE.md)
$GOALOUT"
rm -f "$GLOBAL"

d=$(fixture swstallon)
printf "$GOALMD" > "$d/ROADMAP.md"
printf 'ordo stall_watch: on\n' > "$d/CLAUDE.md"
check "control: stall_watch on, output unchanged" "$d" "$(json_cwd "$d")" "$W
$GOALOUT"

d=$(fixture swignored)
printf "$GOALMD" > "$d/ROADMAP.md"
printf 'ordo nonsense_key: off\nordo qa_check: maybe\n- ordo plan_review: off\nordo Plan_Review: off\nordo plan_review: OFF\nplease set ordo plan_review: off\n' > "$d/CLAUDE.md"
check "unknown key, invalid value, bulleted and prose lines ignored" "$d" "$(json_cwd "$d")" "$W
$GOALOUT"

d=$(fixture swlast)
printf "$GOALMD" > "$d/ROADMAP.md"
printf 'ordo qa_check: off\r\nordo qa_check: on\r\nordo plan_review: on\n  ordo plan_review: off  \nordo plan_review: maybe\n' > "$d/CLAUDE.md"
check "last valid line wins; CRLF and padding allowed; invalid value does not override" "$d" "$(json_cwd "$d")" "$W
ordo: switched off: plan_review (project CLAUDE.md)
$GOALOUT"

printf 'ordo qa_check: off\n' > "$GLOBAL"
d=$(fixture swbadproj)
printf "$GOALMD" > "$d/ROADMAP.md"
printf 'ordo qa_check: off\n\xff\xfe\n' > "$d/CLAUDE.md"
check "non-UTF-8 project CLAUDE.md counts as silent: global decides" "$d" "$(json_cwd "$d")" "$W
ordo: switched off: qa_check (~/.claude/CLAUDE.md)
$GOALOUT"
rm -f "$GLOBAL"

d=$(fixture swbad)
printf "$GOALMD" > "$d/ROADMAP.md"
printf 'ordo qa_check: off\n\xff\xfe\n' > "$d/CLAUDE.md"
check "non-UTF-8 CLAUDE.md, no global: counts as on, no line" "$d" "$(json_cwd "$d")" "$W
$GOALOUT"

d=$(fixture swmissing)
printf "$GOALMD" > "$d/ROADMAP.md"
check "missing CLAUDE.md: counts as on, no line" "$d" "$(json_cwd "$d")" "$W
$GOALOUT"

d=$(fixture swnoroad)
printf 'ordo po_acceptance_tier2: off\n' > "$d/CLAUDE.md"
check "switched-off line still printed when ROADMAP.md is missing" "$d" "$(json_cwd "$d")" "$W
ordo: switched off: po_acceptance_tier2 (project CLAUDE.md)"

d=$(fixture swnogoal)
printf '# Roadmap\n## Other\nstuff\n' > "$d/ROADMAP.md"
printf 'ordo po_acceptance_tier2: off\n' > "$d/CLAUDE.md"
check "switched-off line still printed when ROADMAP.md has no goal" "$d" "$(json_cwd "$d")" "$W
ordo: switched off: po_acceptance_tier2 (project CLAUDE.md)"

d=$(fixture swcwd)
printf 'ordo git_rules: off\n' > "$d/CLAUDE.md"
run_hook "$d" ''
[ "$rc" = 0 ] && [ -z "$err" ] && [ "$out" = "$W
ordo: switched off: git_rules (project CLAUDE.md)" ] && pass "no stdin cwd: process cwd CLAUDE.md is used" || fail "process cwd switch (rc=$rc err=[$err] out=[$out])"

# AC41: no file written, not even a .pyc from importing guard_bash
d=$(fixture nowrite)
mkdir -p "$d/hooks" "$d/proj"
cp "$goal" "$d/hooks/goal_context.py"
cp "$(dirname "$goal")/guard_bash.py" "$d/hooks/guard_bash.py"
printf 'ordo qa_check: off\n' > "$d/proj/CLAUDE.md"
before=$(cd "$d" && find . | sort)
out=$(cd "$d/proj" && printf '%s' "$(json_cwd "$d/proj")" | env -u PYTHONDONTWRITEBYTECODE python3 "$d/hooks/goal_context.py" 2>/dev/null) || true
after=$(cd "$d" && find . | sort)
case "$out" in *"switched off: qa_check"*) ;; *) fail "nowrite control: switch line missing [$out]" ;; esac
[ "$before" = "$after" ] && pass "hook writes no file (no __pycache__ next to the hook)" || fail "hook wrote files: $(diff <(echo "$before") <(echo "$after") | tr '\n' ' ')"

# HOME empty: no relative global path <cwd>/.claude/CLAUDE.md
d=$(fixture swnohome)
mkdir -p "$d/.claude"
printf 'ordo qa_check: off\n' > "$d/.claude/CLAUDE.md"
out=$(cd "$d" && printf '%s' "$(json_cwd "$d")" | HOME= python3 "$goal" 2>"$work/err") && rc=0 || rc=$?
[ "$rc" = 0 ] && [ ! -s "$work/err" ] && [ "$out" = "$W" ] && pass "HOME empty: no global level, no switch line" || fail "HOME empty (rc=$rc out=[$out])"

d=$(fixture parent)
printf '## Current goal\nParent: ship-it\nDo the thing.\n' > "$d/ROADMAP.md"
check "Parent: line kept" "$d" "$(json_cwd "$d")" "$W
$H
Parent: ship-it
Do the thing."

d=$(fixture none)
check "no ROADMAP.md" "$d" "$(json_cwd "$d")" "$W"

d=$(fixture nosection)
printf '# Roadmap\n## Other\nstuff\n' > "$d/ROADMAP.md"
check "no section" "$d" "$(json_cwd "$d")" "$W"

d=$(fixture empty)
printf '## Current goal\n\n   \n## Other\nstuff\n' > "$d/ROADMAP.md"
check "empty section" "$d" "$(json_cwd "$d")" "$W"

d=$(fixture second)
printf '## First\nalpha\n## Current goal\nbeta\n' > "$d/ROADMAP.md"
check "heading not first H2" "$d" "$(json_cwd "$d")" "$W
$H
beta"

d=$(fixture ends)
printf '## Current goal\none\n### sub\ntwo\n## Next\nthree\n' > "$d/ROADMAP.md"
check "section ends at next ## (### stays)" "$d" "$(json_cwd "$d")" "$W
$H
one
### sub
two"

d=$(fixture crlf)
printf '## Current goal  \r\nalpha\r\nbeta\r\n## Next\r\nx\r\n' > "$d/ROADMAP.md"
check "CRLF file, trailing spaces on heading" "$d" "$(json_cwd "$d")" "$W
$H
alpha
beta"

d=$(fixture badutf)
printf '## Current goal\nbad \xff\xfe byte\n' > "$d/ROADMAP.md"
check "non-UTF-8 file" "$d" "$(json_cwd "$d")" "$W"

d=$(fixture isdir)
mkdir "$d/ROADMAP.md"
check "ROADMAP.md is a directory" "$d" "$(json_cwd "$d")" "$W"

d=$(fixture lines)
{ echo '## Current goal'; for i in $(seq 1 20); do echo "line $i"; done; } > "$d/ROADMAP.md"
check "truncated at 15 lines" "$d" "$(json_cwd "$d")" "$W
$H
line 1
line 2
line 3
line 4
line 5
line 6
line 7
line 8
line 9
line 10
line 11
line 12
line 13
line 14
line 15
$T"

d=$(fixture exact15)
{ echo '## Current goal'; for i in $(seq 1 15); do echo "line $i"; done; } > "$d/ROADMAP.md"
check "exactly 15 lines not truncated" "$d" "$(json_cwd "$d")" "$W
$H
line 1
line 2
line 3
line 4
line 5
line 6
line 7
line 8
line 9
line 10
line 11
line 12
line 13
line 14
line 15"

d=$(fixture planline)
printf '## Current goal\nShip plans in the repo.\nPlan: docs/plans/2026-11-15-plans-in-repo.md\nParent: x\n\n## Next\nz\n' > "$d/ROADMAP.md"
check "Plan: line right after the goal sentence is printed" "$d" "$(json_cwd "$d")" "$W
$H
Ship plans in the repo.
Plan: docs/plans/2026-11-15-plans-in-repo.md
Parent: x"

d=$(fixture bytes)
a300=$(head -c 300 /dev/zero | tr '\0' a)
{ echo '## Current goal'; for i in 1 2 3 4 5; do echo "$a300"; done; } > "$d/ROADMAP.md"
check "truncated by 1200 bytes (3 whole 301-byte lines fit)" "$d" "$(json_cwd "$d")" "$W
$H
$a300
$a300
$a300
$T"

d=$(fixture malformed)
printf '## Current goal\nfallback\n' > "$d/ROADMAP.md"
run_hook "$d" 'not json {'
[ "$rc" = 0 ] && [ -z "$err" ] && [ "$out" = "$W
$H
fallback" ] && pass "malformed stdin falls back to cwd" || { fail "malformed stdin (rc=$rc err=[$err] out=[$out])"; }
run_hook "$d" ''
[ "$rc" = 0 ] && [ -z "$err" ] && [ "$out" = "$W
$H
fallback" ] && pass "empty stdin falls back to cwd" || { fail "empty stdin (rc=$rc err=[$err] out=[$out])"; }
run_hook "$d" '{"cwd": 5}'
[ "$rc" = 0 ] && [ -z "$err" ] && [ "$out" = "$W
$H
fallback" ] && pass "non-string cwd falls back to cwd" || { fail "non-string cwd (rc=$rc err=[$err] out=[$out])"; }

d=$(fixture elsewhere)
mkdir -p "$d/proj" "$d/other"
printf '## Current goal\nfrom proj\n' > "$d/proj/ROADMAP.md"
printf '## Current goal\nfrom other\n' > "$d/other/ROADMAP.md"
run_hook "$d/other" "$(json_cwd "$d/proj")"
[ "$rc" = 0 ] && [ -z "$err" ] && [ "$out" = "$W
$H
from proj" ] && pass "stdin cwd wins over process cwd" || { fail "stdin cwd (rc=$rc err=[$err] out=[$out])"; }

d=$(fixture big)
{ echo '## Current goal'; echo 'big file goal'; head -c 5000000 /dev/zero | tr '\0' x; echo; } > "$d/ROADMAP.md"
check "5 MB ROADMAP.md: workflow line, goal header, first line, truncation marker" "$d" "$(json_cwd "$d")" "$W
$H
big file goal
$T"

d=$(fixture bigns)
head -c 5000000 /dev/zero | tr '\0' x > "$d/ROADMAP.md"
check "5 MB ROADMAP.md without a goal section: only the workflow line" "$d" "$(json_cwd "$d")" "$W"

# AC2/AC4: with no goal, stdout is exactly one line (newline-terminated), exit 0, empty stderr; AC6: byte bound on the line
d=$(fixture noroadmap)
run_hook "$d" "$(json_cwd "$d")"
lines=$(printf '%s\n' "$out" | wc -l | tr -d ' ')
[ "$rc" = 0 ] && [ -z "$err" ] && [ "$lines" = 1 ] && pass "no goal: exactly one line, exit 0, empty stderr" || fail "no goal one line (rc=$rc lines=$lines err=[$err])"
bytes=$(printf '%s' "$out" | wc -c | tr -d ' ')
[ "$bytes" -le 150 ] && pass "workflow line is at most 150 bytes ($bytes)" || fail "workflow line too long ($bytes bytes)"
for stdin in 'not json {' '' '{"cwd": 5}'; do
  run_hook "$d" "$stdin"
  [ "$rc" = 0 ] && [ -z "$err" ] && [ "$out" = "$W" ] && pass "no goal, stdin [$stdin]: only the workflow line" || fail "no goal, stdin [$stdin] (rc=$rc err=[$err] out=[$out])"
done
d=$(fixture missingdir)
check "cwd that does not exist: only the workflow line" "$d" "$(json_cwd "$d/nope")" "$W"

# hooks.json: PreToolUse entries equal a pinned value; the usage hook's other entries present
U='{"type":"command","command":"python3 \"${CLAUDE_PLUGIN_ROOT}/hooks/usage_log.py\"","timeout":5}'
want='[{"hooks":[{"command":"python3 \"${CLAUDE_PLUGIN_ROOT}/hooks/guard_bash.py\"","timeout":10,"type":"command"}],"matcher":"Bash"},{"hooks":['"$(printf '%s' "$U" | jq -S -c .)"'],"matcher":"Skill|Agent|Bash|Monitor"}]'
got=$(jq -S -c '.hooks.PreToolUse' "$root/plugins/ordo/hooks/hooks.json")
[ "$want" = "$got" ] && pass "PreToolUse entries equal the pinned value" || fail "PreToolUse entries differ from the pinned value: $got"
ss=$(jq -c '.hooks.SessionStart' "$root/plugins/ordo/hooks/hooks.json")
[ "$ss" = '[{"matcher":"startup|resume|compact","hooks":[{"type":"command","command":"python3 \"${CLAUDE_PLUGIN_ROOT}/hooks/goal_context.py\"","timeout":5}]},{"matcher":"startup|clear","hooks":['"$U"']}]' ] \
  && pass "SessionStart entries" || fail "SessionStart entries: $ss"
se=$(jq -c '.hooks.SessionEnd' "$root/plugins/ordo/hooks/hooks.json")
[ "$se" = '[{"hooks":['"$U"']}]' ] && pass "SessionEnd entry" || fail "SessionEnd entry: $se"
pa=$(jq -c '.hooks.PostToolUse' "$root/plugins/ordo/hooks/hooks.json")
[ "$pa" = '[{"matcher":"Agent|Skill|Bash|Monitor","hooks":['"$U"']}]' ] && pass "PostToolUse entry" || fail "PostToolUse entry: $pa"
pf=$(jq -c '.hooks.PostToolUseFailure' "$root/plugins/ordo/hooks/hooks.json")
[ "$pf" = '[{"matcher":"Agent|Skill|Bash|Monitor","hooks":['"$U"']}]' ] && pass "PostToolUseFailure entry" || fail "PostToolUseFailure entry: $pf"
for ev in PermissionRequest PermissionDenied; do
  pr=$(jq -c ".hooks.$ev" "$root/plugins/ordo/hooks/hooks.json")
  [ "$pr" = '[{"matcher":"Skill|Agent|Bash|Monitor","hooks":['"$U"']}]' ] && pass "$ev entry" || fail "$ev entry: $pr"
done
for ev in SubagentStart SubagentStop; do
  pr=$(jq -c ".hooks.$ev" "$root/plugins/ordo/hooks/hooks.json")
  [ "$pr" = '[{"hooks":['"$U"']}]' ] && pass "$ev entry" || fail "$ev entry: $pr"
done

echo
if [ "$fails" -eq 0 ]; then echo "all passed"; else echo "$fails failed"; exit 1; fi
