#!/bin/bash
# Tests for scripts/eval-audit.sh. Free: fixture JSON only, no agent runs.
# The no-argument default (newest suite-*/ folder) is tested on a temp copy of the layout:
# scripts/eval-audit.sh is copied to <tmp>/scripts/ and fake results go under
# <tmp>/plugins/ordo/evals/results/, because the script finds the repo root from its own location.
set -uo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
script="$root/scripts/eval-audit.sh"
fx="$root/scripts/fixtures/eval-audit"
tmp_root=${TMPDIR:-/tmp}
tmp_root=${tmp_root%/}
work=$(mktemp -d "$tmp_root/eval-audit-test.XXXXXX")
cleanup() {
  if [ -n "${work:-}" ] && [ -d "$work" ] && [ "${work#"$tmp_root"/}" != "$work" ]; then
    rm -r "$work"
  fi
}
trap cleanup EXIT

pass=0; fail=0
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "FAIL: $1"; [ -n "${2:-}" ] && echo "$2" | sed 's/^/    /'; }
eq()  { [ "$2" = "$3" ] && ok || bad "$1" "expected: $2
actual:   $3"; }

# run <args...>: sets out, err, rc. Squeezes runs of spaces so the column padding does not matter.
run() {
  out=$(bash "$script" "$@" 2>"$work/err"); rc=$?
  err=$(cat "$work/err")
  out=$(printf '%s\n' "$out" | tr -s ' ')
}
row() { printf '%s\n' "$out" | awk -v n="$1" '$1 == n'; }

# --- 1. fixture table, hand-computed -----------------------------------------------
# Fixture batch-a.json + batch-b.json (split is pooled across both). Run = passed true AND error null.
#  all-pass  3 runs, 3 pass -> 100.0%; cost (0.10+0.20+0.30)/3 = 0.20; dur (10+20+30)/3 = 20
#  all-fail  3 runs, 0 pass -> 0.0%;   cost 0.50;                       dur (40+50+60)/3 = 50
#  flaky     3 runs, 2 pass -> 66.7%;  cost 0.30;                       dur 30; flake (0 < 2/3 < 1)
#  errored   1 run passed=true but error="timeout" -> 0 pass -> 0.0%; cost 0.45; dur 15; no flake (0/1)
#  split     a: 2 runs (1 pass), b: 1 run (1 pass) -> 3 runs, 2 pass -> 66.7%;
#            cost (0.10+0.20+0.90)/3 = 0.40; dur (10+20+60)/3 = 30; flake
#  tie-a/b   1 run each, passed, cost 0.25 both -> rate 100.0%, no flake (single run), share rank
#  empty-arms, no-arms: 0 runs -> n/a everywhere, no flake, no rank
# Rank (1 = highest avg cost): all-fail 0.50 ->1, errored 0.45 ->2, split 0.40 ->3, flaky 0.30 ->4,
#  tie-a & tie-b 0.25 ->5 (both), all-pass 0.20 ->7 (competition ranking: next rank skips the tie).
run "$fx/batch-a.json" "$fx/batch-b.json"
eq "fixture exit code" 0 "$rc"
eq "header" "CASE RUNS PASS_RATE AVG_COST_USD AVG_DURATION_S FLAKE COST_RANK" "$(printf '%s\n' "$out" | sed -n 1p)"
eq "row order and values" "all-fail 3 0.0% 0.5000 50.0 no 1
errored 1 0.0% 0.4500 15.0 no 2
split 3 66.7% 0.4000 30.0 yes 3
flaky 3 66.7% 0.3000 30.0 yes 4
tie-a 1 100.0% 0.2500 5.0 no 5
tie-b 1 100.0% 0.2500 7.0 no 5
all-pass 3 100.0% 0.2000 20.0 no 7
empty-arms 0 n/a n/a n/a no n/a
no-arms 0 n/a n/a n/a no n/a" "$(printf '%s\n' "$out" | sed -n '2,$p')"
eq "flake only on 2/3 cases" "flaky split" "$(printf '%s\n' "$out" | awk 'NR>1 && $6=="yes"{print $1}' | sort | tr '\n' ' ' | sed 's/ $//')"

# --- 2. pooling: same case in two files is one row; alone it has fewer runs ---------
run "$fx/batch-a.json"
# split alone: 2 runs, 1 pass = 50.0%; cost (0.10+0.20)/2 = 0.15; dur (10+20)/2 = 15; flake;
# six cases average more (0.50 0.45 0.30 0.25 0.25 0.20) -> rank 7.
eq "split alone: 2 runs, 1 pass" "split 2 50.0% 0.1500 15.0 yes 7" "$(row split)"
eq "split appears once when pooled" 1 "$( { bash "$script" "$fx/batch-a.json" "$fx/batch-b.json" | awk '$1=="split"'; } | wc -l | tr -d ' ')"

# --- 3. no-arg default: newest suite-*/ folder, *.json only --------------------------
repo="$work/repo"
res="$repo/plugins/ordo/evals/results"
mkdir -p "$repo/scripts" "$res/suite-20260101-000000" "$res/suite-20260202-000000"
cp "$script" "$repo/scripts/"
cp "$fx/batch-b.json" "$res/suite-20260101-000000/old.json"          # older folder: must be ignored
cp "$fx/batch-a.json" "$res/suite-20260202-000000/new.json"          # newest folder
echo "not a results file" > "$res/suite-20260202-000000/new.log"     # non-json ignored
echo 0 > "$res/suite-20260202-000000/new.exit"
out=$(bash "$repo/scripts/eval-audit.sh" 2>"$work/err"); rc=$?; out=$(printf '%s\n' "$out" | tr -s ' ')
eq "no-arg exit code" 0 "$rc"
eq "no-arg uses newest folder only (split has 2 runs, not 3)" "split 2 50.0% 0.1500 15.0 yes 7" "$(row split)"
# no results folder at all -> exit 2
empty="$work/empty"; mkdir -p "$empty/scripts" "$empty/plugins/ordo/evals/results"; cp "$script" "$empty/scripts/"
bash "$empty/scripts/eval-audit.sh" >/dev/null 2>"$work/err"; rc=$?
eq "no-arg, no suite folder: exit 2" 2 "$rc"
[ -s "$work/err" ] && ok || bad "no-arg, no suite folder: stderr message"

# --- 4. bad input --------------------------------------------------------------------
run "$work/does-not-exist.json"
eq "missing file: exit" 2 "$rc"
case "$err" in *"does-not-exist.json"*) ok ;; *) bad "missing file: message names the file" "$err" ;; esac
eq "missing file: stdout empty" "" "$out"

unreadable="$work/unreadable.json"; cp "$fx/batch-a.json" "$unreadable"; chmod 000 "$unreadable"
if [ "$(id -u)" -ne 0 ]; then
  run "$unreadable"
  eq "unreadable file: exit" 2 "$rc"
  case "$err" in *"unreadable.json"*) ok ;; *) bad "unreadable file: message names the file" "$err" ;; esac
fi
chmod 644 "$unreadable"

run "$fx/invalid.json"
[ "$rc" -ne 0 ] && ok || bad "invalid JSON: non-zero exit"
case "$err" in *"invalid.json"*) ok ;; *) bad "invalid JSON: message names the file" "$err" ;; esac
eq "invalid JSON: stdout empty" "" "$out"

# --- 4b. wrong shape: valid JSON that is not a results file -> exit 1, message, no table -------
for bf in bad-shape bad-arms cases-object; do
  run "$fx/$bf.json"
  eq "$bf: exit 1" 1 "$rc"
  case "$err" in *"eval-audit:"*) ok ;; *) bad "$bf: eval-audit message" "$err" ;; esac
  case "$err" in *"$bf.json"*) ok ;; *) bad "$bf: message names the file" "$err" ;; esac
  eq "$bf: stdout empty (no header-only table)" "" "$out"
done
# string costUsd must fail cleanly too (inline file in the temp dir)
echo '{"cases":[{"name":"s","arms":{"with":[{"passed":true,"error":null,"costUsd":"1.0","durationSeconds":1}]}}]}' > "$work/strcost.json"
run "$work/strcost.json"
eq "string costUsd: exit 1" 1 "$rc"
case "$err" in *"eval-audit:"*) ok ;; *) bad "string costUsd: eval-audit message" "$err" ;; esac

# zero cases: header only, exit 0, no fake row (a case-less file is valid, just empty)
for ef in empty-cases empty-object; do
  run "$fx/$ef.json"
  eq "$ef: exit 0" 0 "$rc"
  eq "$ef: header only" "CASE RUNS PASS_RATE AVG_COST_USD AVG_DURATION_S FLAKE COST_RANK" "$out"
done

# --- 4c. odd runs: unnamed case, truthy passed ------------------------------------------
# odd-runs.json: case without name -> shown as (unnamed): 1 run, passed true, cost 0.10, dur 10 -> 100.0% 0.1000 10.0, rank 1.
# truthy: passed=1 (truthy, as in run-eval-suite.sh), error null -> counts as pass: 100.0%, cost 0.05, dur 4, rank 2.
run "$fx/odd-runs.json"
eq "unnamed case row" "(unnamed) 1 100.0% 0.1000 10.0 no 1" "$(printf '%s\n' "$out" | sed -n 2p)"
eq "truthy passed counts as pass" "truthy 1 100.0% 0.0500 4.0 no 2" "$(row truthy)"

run "$fx/batch-a.json" "$fx/invalid.json"
[ "$rc" -ne 0 ] && ok || bad "one good, one invalid: non-zero exit"
eq "one good, one invalid: no partial table" "" "$out"

# no jq on PATH -> exit 2 with a message
nojq="$work/nojq"; mkdir -p "$nojq"
err=$(PATH="$nojq" /bin/bash "$script" "$fx/batch-a.json" 2>&1 >/dev/null); rc=$?
eq "no jq: exit" 2 "$rc"
case "$err" in *jq*) ok ;; *) bad "no jq: message mentions jq" "$err" ;; esac

# --- 5. list only: nothing written, edited or deleted --------------------------------
sum_tree() { # checksum of the fixtures, the scratch results tree and every tracked file in the repo
  { find "$fx" "$res" -type f -exec shasum {} + ; git -C "$root" ls-files -z | (cd "$root" && xargs -0 -I{} sh -c 'test -f "{}" && shasum "{}"'); } 2>/dev/null | sort | shasum
}
before=$(sum_tree)
bash "$script" "$fx/batch-a.json" "$fx/batch-b.json" >/dev/null 2>&1
bash "$repo/scripts/eval-audit.sh" >/dev/null 2>&1
bash "$script" "$work/does-not-exist.json" >/dev/null 2>&1
bash "$script" "$fx/invalid.json" >/dev/null 2>&1
after=$(sum_tree)
eq "no file changed (fixtures, results tree, tracked files)" "$before" "$after"
eq "no new file in fixture dir" "bad-arms.json
bad-shape.json
batch-a.json
batch-b.json
cases-object.json
empty-cases.json
empty-object.json
invalid.json
odd-runs.json" "$(ls "$fx")"

echo "eval-audit tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
