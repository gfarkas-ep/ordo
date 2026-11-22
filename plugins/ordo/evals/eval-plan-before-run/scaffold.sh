#!/bin/bash
# A small fake plugin (acme-plugin) with three eval cases and the results JSON of its last run.
# Known figures (per case, 3 prior runs each): login-flow 0.20 USD / 60 s, export-csv 0.30 USD / 120 s,
# refund-policy 0.50 USD / 180 s per run; passed 3/3, 3/3, 2/3 = 8/9.
set -e
mkdir -p acme-plugin/evals/login-flow acme-plugin/evals/export-csv acme-plugin/evals/refund-policy acme-plugin/evals/results
for c in login-flow export-csv refund-policy; do
  printf -- '---\nname: %s\ndescription: "%s check"\ntags: [acme]\nruns: 3\n---\n\nCheck the %s behaviour.\n' "$c" "$c" "$c" > "acme-plugin/evals/$c/prompt.md"
done
run() { # passed cost seconds
  printf '{"passed": %s, "score": 1, "error": null, "graders": [], "costUsd": %s, "durationSeconds": %s}' "$1" "$2" "$3"
}
{
  printf '{"cases": [\n'
  printf '{"name": "login-flow", "arms": {"with": [%s, %s, %s]}},\n' "$(run true 0.20 60)" "$(run true 0.20 60)" "$(run true 0.20 60)"
  printf '{"name": "export-csv", "arms": {"with": [%s, %s, %s]}},\n' "$(run true 0.30 120)" "$(run true 0.30 120)" "$(run true 0.30 120)"
  printf '{"name": "refund-policy", "arms": {"with": [%s, %s, %s]}}\n' "$(run true 0.50 180)" "$(run false 0.50 180)" "$(run true 0.50 180)"
  printf ']}\n'
} > acme-plugin/evals/results/last.json
