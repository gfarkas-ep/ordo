#!/bin/bash
# Audits eval results: one row per case, pooled by name across all inputs. Lists only: reads the
# results JSON and prints a table; it never writes, edits or deletes any file. Needs jq.
#
# usage: eval-audit.sh [RESULTS.json ...]
#   With no arguments: every *.json in the newest plugins/ordo/evals/results/suite-*/ folder
#   (found relative to this script's repo root).
# Columns: CASE RUNS PASS_RATE AVG_COST_USD AVG_DURATION_S FLAKE COST_RANK
#   A run passes only if passed is true and error is null (same rule as run-eval-suite.sh).
#   PASS_RATE = passed runs / runs. FLAKE = yes iff 0 < pass rate < 1 (single-run cases never flake).
#   COST_RANK 1 = highest average cost; ties share a rank and the next rank is skipped (1,2,2,4).
#   Cases with no runs (arms.with missing or empty) show n/a and sort last.
#   A null or missing costUsd or durationSeconds counts as 0 in the averages.
#   A case without a name is listed as (unnamed).
# Rows are sorted by cost rank, then name.
# Exit 2 for usage or dependency errors (no jq, no results folder); 1 for an input that is not valid JSON or not a results file (wrong shape).
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)

command -v jq >/dev/null 2>&1 || { echo "eval-audit: jq is required but not found on PATH" >&2; exit 2; }

files=("$@")
if [ ${#files[@]} -eq 0 ]; then
  results="$root/plugins/ordo/evals/results"
  newest=""
  for d in "$results"/suite-*/; do
    [ -d "$d" ] && newest=${d%/}   # glob sorts by name; the timestamp in the name makes the last one newest
  done
  [ -n "$newest" ] || { echo "eval-audit: no suite-*/ folder in $results; pass results JSON paths" >&2; exit 2; }
  for f in "$newest"/*.json; do
    [ -f "$f" ] && files+=("$f")
  done
  [ ${#files[@]} -gt 0 ] || { echo "eval-audit: no *.json files in $newest" >&2; exit 2; }
fi

for f in "${files[@]}"; do
  [ -f "$f" ] && [ -r "$f" ] || { echo "eval-audit: cannot read '$f'" >&2; exit 2; }
  jq -e 'type == "object"' "$f" >/dev/null 2>&1 || { echo "eval-audit: '$f' is not valid JSON (expected an object with .cases)" >&2; exit 1; }
done

# jq pools, counts and ranks; awk only formats numbers (jq has no printf).
rows=$(jq -r -n '
  [ inputs | (.cases // [] | if type == "array" then .[] else error("cases is not an array") end) | {name: (.name // "(unnamed)"), runs: (.arms.with // [])}
    | if (.runs | type) == "array" then . else error("arms.with is not an array") end ]
  | group_by(.name)
  | map(
      (map(.runs) | add) as $runs
      | ($runs | length) as $n
      | ($runs | map(select(.passed and (.error == null))) | length) as $p
      | if $n == 0 then
          {name: .[0].name, n: 0, rate: null, cost: null, dur: null, flake: "no"}
        else
          {name: .[0].name, n: $n, rate: ($p / $n),
           cost: ((($runs | map(.costUsd // 0) | add) / $n * 1000000 | round) / 1000000),
           dur: (($runs | map(.durationSeconds // 0) | add) / $n),
           flake: (if $p > 0 and $p < $n then "yes" else "no" end)}
        end)
  | . as $all
  | map(. + {rank: (if .cost == null then null
                    else (.cost as $c | 1 + ($all | map(select(.cost != null and .cost > $c)) | length)) end)})
  | sort_by([(.rank // 1e9), .name])
  | .[] | [.name, .n, (.rate // "n/a"), (.cost // "n/a"), (.dur // "n/a"), .flake, (.rank // "n/a")] | @tsv
' "${files[@]}") || { echo "eval-audit: input is not a results file (cases must be an array of objects, arms.with an array of runs, costUsd and durationSeconds numbers); see the jq error above" >&2; exit 1; }
printf '%s\n' "$rows" \
  | awk -F'\t' -v OFS='\t' '
      BEGIN { print "CASE", "RUNS", "PASS_RATE", "AVG_COST_USD", "AVG_DURATION_S", "FLAKE", "COST_RANK" }
      NF == 0 { next }
      { if ($3 != "n/a") $3 = sprintf("%.1f%%", $3 * 100)
        if ($4 != "n/a") $4 = sprintf("%.4f", $4)
        if ($5 != "n/a") $5 = sprintf("%.1f", $5)
        print }' \
  | column -t -s "$(printf '\t')"
