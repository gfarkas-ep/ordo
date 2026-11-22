#!/bin/bash
# A finished run that deviates from its plan: refund-policy failed 2 of 4 runs, cost 5.60 USD against a 4.00 USD plan.
set -e
mkdir -p results
cat > plan.md <<'MD'
# Eval plan: acme-plugin

## Cases
- login-flow
- export-csv
- refund-policy

Runs: 4 per case (12 runs).

## Expected pass rate
100% (12/12). Last results: 8/9, refund-policy flaked once.

## Budget
- Cost: (0.20 + 0.30 + 0.50) USD per run set x 4 runs = $4.00 (figures from the last results JSON).
- Wall time: (60 + 120 + 180) s x 4 runs = 1440 s (24 min), run one after another.

## Stop rule
Abort when spend passes $6.00 or when any case fails 3 of its 4 runs. A failure is a run with `passed` false or an error.
MD
run() { # passed cost seconds
  printf '{"passed": %s, "score": 1, "error": null, "graders": [], "costUsd": %s, "durationSeconds": %s}' "$1" "$2" "$3"
}
{
  printf '{"cases": [\n'
  printf '{"name": "login-flow", "arms": {"with": [%s]}},\n' "$(run true 0.20 60),$(run true 0.20 60),$(run true 0.20 60),$(run true 0.20 60)"
  printf '{"name": "export-csv", "arms": {"with": [%s]}},\n' "$(run true 0.30 120),$(run true 0.30 120),$(run true 0.30 120),$(run true 0.30 120)"
  printf '{"name": "refund-policy", "arms": {"with": [%s]}}\n' "$(run true 0.90 240),$(run false 0.90 240),$(run true 0.90 240),$(run false 0.90 240)"
  printf ']}\n'
} > results/run.json
