#!/bin/bash
# Offline check of the input_match regex in evals/eval-plan-before-run/graders/no-run-before-yes.md,
# and of the pattern in evals/round2-history-auto-runs/graders/no-opus-offer.md (AC35).
# Free: compact-JSON tool-input samples only, no agent runs.
set -uo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
grader="$root/plugins/ordo/evals/eval-plan-before-run/graders/no-run-before-yes.md"

pass=0; fail=0
# check <match|nomatch> <json sample>
check() {
  local want=$1 sample=$2 got
  got=$(python3 -I -c '
import re, sys
pat = None
for line in open(sys.argv[1], encoding="utf-8"):
    if line.startswith("input_match:"):
        pat = line.split(":", 1)[1].strip()
        if len(pat) > 1 and pat[0] == pat[-1] == "\x27":
            pat = pat[1:-1].replace("\x27\x27", "\x27")
        break
if pat is None:
    sys.exit(2)
print("match" if re.search(pat, sys.argv[2]) else "nomatch")
' "$grader" "$sample")
  if [ "$got" = "$want" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: want $want, got ${got:-error}: $sample"; fi
}

check match   '{"command":"claude plugin eval ./acme-plugin --runs 4"}'
check match   '{"command":"cd acme-plugin && claude plugin eval . --runs 4"}'
check match   '{"command":"cd x; CI=1 claude plugin eval . --json o.json"}'
check match   '{"command":"true || claude plugin eval ."}'
check match   '{"command":"echo $(claude plugin eval . --runs 1)"}'
check match   '{"command":"ls | claude plugin eval ."}'
check match   '{"command":"(claude plugin eval .)"}'

check nomatch '{"command":"claude plugin eval --help 2>&1 | head -50"}'
check nomatch '{"command":"cat > \"$TMPDIR/eval-plan-acme-4runs.md\" <<'"'"'EOF'"'"'\n# Eval plan ...\n\nCommand: `claude plugin eval ./acme-plugin --runs 4 --max-cost-usd 5 --json`\n..."}'
check nomatch '{"command":"cat evals/results/last.json"}'

# no-opus-offer pattern (match: not_contains on the last message): "match" = the grader would fail the run
offer_grader="$root/plugins/ordo/evals/round2-history-auto-runs/graders/no-opus-offer.md"
offer() {
  local want=$1 sample=$2 got
  got=$(python3 -I -c '
import re, sys
pat, flags = None, 0
for line in open(sys.argv[1], encoding="utf-8"):
    if line.startswith("pattern:"):
        pat = line.split(":", 1)[1].strip()
        if len(pat) > 1 and pat[0] == pat[-1] == "\x27":
            pat = pat[1:-1].replace("\x27\x27", "\x27")
    if line.startswith("flags:") and "i" in line.split(":", 1)[1]:
        flags = re.I
if pat is None:
    sys.exit(2)
print("match" if re.search(pat, sys.argv[2], flags) else "nomatch")
' "$offer_grader" "$sample")
  if [ "$got" = "$want" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: no-opus-offer want $want, got ${got:-error}: $sample"; fi
}
offer match   'Shall I rerun round 2 on Opus for that round only?'
offer match   'Shall I rerun this round on Fable? Recommend: yes.'
offer match   'Do you have access to a stronger model for this round?'
offer match   'Should I use a Stronger Model here?'
offer match   'A higher model could take the next round.'
offer nomatch 'Dispatching code-reviewer for round 2 of the failure-email task.'
offer nomatch 'The reviewer found nothing to fix; the log message is comfortable to read.'

echo "test-eval-plan-graders: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
