#!/bin/bash
# Pins .github/workflows/ci.yml (publish AC10, AC11) and runs its test-running step against stub scripts. Free: reads repo files only.
# The step's shell sits between the markers "# BEGIN ci-test-step" and "# END ci-test-step" in the workflow, so it can be cut out without a YAML parser.
set -uo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root" || exit 2
wf=.github/workflows/ci.yml

pass=0; fail=0
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "FAIL: $1"; }
eq()  { [ "$2" = "$3" ] && ok || bad "$1 (expected '$2', got '$3')"; }
has() { grep -qF -- "$2" "$3" && ok || bad "$1: '$2' missing in $3"; }

[ -f "$wf" ] && ok || { bad "$wf missing"; echo "pass=$pass fail=$fail"; exit 1; }

job_keys()  { awk '/^jobs:/{j=1;next} j&&/^[^ ]/{j=0} j&&/^  [A-Za-z0-9_-]+:/{sub(/^  /,"");sub(/:.*/,"");print}' "$wf"; }
job_block() { awk -v j="$1" '/^jobs:/{i=1;next} i&&/^[^ ]/{i=0} i&&/^  [A-Za-z0-9_-]+:/{p=($0=="  " j ":")} p' "$wf"; }
step_shell() { # job: the shell between the two markers, indented as in the file
  job_block "$1" | awk '/# END ci-test-step/{p=0} p{print} /# BEGIN ci-test-step/{p=1}'
}

# --- structure (AC10, AC11) ---
eq "exactly one job, named linux" "linux" "$(job_keys | tr '\n' ' ' | sed 's/ $//')"
has "triggers: push" '  push:' "$wf"
has "triggers: pull_request" '  pull_request:' "$wf"
eq "linux job runs on ubuntu-latest" 1 "$(job_block linux | grep -cE '^    runs-on: ubuntu-latest$')"
eq "workflow has no continue-on-error" 0 "$(grep -c 'continue-on-error' "$wf")"
eq "permissions: contents: read, nothing else" "permissions:|  contents: read" "$(awk '/^permissions:/{p=1} p&&/^[^ ]/&&!/^permissions:/{p=0} p&&NF' "$wf" | paste -sd'|' -)"
for j in linux; do
  eq "$j: checkout by version tag" 1 "$(job_block $j | grep -cE 'uses: actions/checkout@v[0-9]+$')"
  eq "$j: installs jq and rsync when missing" 1 "$(job_block $j | grep -cF 'command -v jq')"
  eq "$j: exactly these steps, in this order: checkout, install, test (any extra step fails; publish AC12)" "      - uses: actions/checkout@v4|      - name: Install jq and rsync when missing|      - name: Run every test script" "$(job_block $j | grep -E '^      - ' | paste -sd'|' -)"
  eq "$j: exactly two run steps (install, test)" 2 "$(job_block $j | grep -cE '^        run:')"
  eq "$j: has the test-running step markers once" "1 1" "$(job_block $j | grep -c '# BEGIN ci-test-step') $(job_block $j | grep -c '# END ci-test-step')"
done
eq "workflow has exactly three steps" 3 "$(grep -cE '^      - ' "$wf")"
if grep -qE 'uses: [^ ]+@[0-9a-f]{40}' "$wf"; then bad "an action is pinned by SHA (Dependabot alerts cover tagged actions only)"; else ok; fi
if grep -qE 'secrets\.|ANTHROPIC|claude plugin eval|run-eval-suite' "$wf"; then bad "workflow uses a secret or a paid model call"; else ok; fi
# the test step's run block holds nothing but the marked step: no line outside BEGIN/END other than blank (a `trap ... EXIT` there would turn the check green)
test_step() { job_block "$1" | awk '/^      - /{p=($0=="      - name: Run every test script")} p'; }
for j in linux; do
  eq "$j: the test step is the only one named 'Run every test script'" 1 "$(job_block $j | grep -cF -- '- name: Run every test script')"
  eq "$j: the test step is name, shell: bash, run: | and the marked body" "      - name: Run every test script|        shell: bash|        run: |" "$(test_step $j | awk '/^        run: \|$/{print;exit} {print}' | paste -sd'|' -)"
  eq "$j: nothing in the test step's body outside the markers" "" "$(test_step $j | awk '/^        run: \|$/{b=1;next} b' | awk '/# END ci-test-step/{p=0;next} /# BEGIN ci-test-step/{p=1;next} !p&&NF' | paste -sd'|' -)"
done
if command -v ruby >/dev/null 2>&1; then
  ruby -ryaml -e 'YAML.load_file(ARGV[0])' "$wf" >/dev/null 2>&1 && ok || bad "$wf is not valid YAML"
else
  echo "note: ruby missing, YAML parse of the workflow skipped"
fi

# --- the test-running step: any failing script fails it, not only the last (AC11) ---
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
step_shell linux | sed 's/^ *//' > "$tmp/step.sh"
[ -s "$tmp/step.sh" ] && ok || bad "no shell between the markers"
# run_step <name>: GitHub runs a `shell: bash` step as `bash --noprofile --norc -eo pipefail`, so the step runs that way here; a temp tree whose scripts/ holds the stubs listed on stdin as "<file> <exit code>"; prints "<exit code>" then the step's output
run_step() {
  local d="$tmp/$1"; mkdir -p "$d/scripts"
  while read -r f code; do printf '#!/bin/bash\necho "%s: last line"\nexit %s\n' "$f" "$code" > "$d/scripts/$f"; done
  (cd "$d" && bash --noprofile --norc -eo pipefail "$tmp/step.sh" 2>&1; echo "exit=$?") > "$tmp/$1.out"
}
exit_of() { sed -n 's/^exit=//p' "$tmp/$1.out"; }
printf 'test-a.sh 0\ntest-b.sh 0\ntest-c.sh 0\n' | run_step allpass
eq "all stubs pass: step exits 0" 0 "$(exit_of allpass)"
printf 'test-a.sh 1\ntest-b.sh 0\ntest-c.sh 0\n' | run_step first
eq "first script fails: step exits non-zero" 1 "$([ "$(exit_of first)" != 0 ] && echo 1 || echo 0)"
printf 'test-a.sh 0\ntest-b.sh 1\ntest-c.sh 0\n' | run_step middle
eq "middle script fails: step exits non-zero" 1 "$([ "$(exit_of middle)" != 0 ] && echo 1 || echo 0)"
printf 'test-a.sh 0\ntest-b.sh 0\ntest-c.sh 1\n' | run_step last
eq "last script fails: step exits non-zero" 1 "$([ "$(exit_of last)" != 0 ] && echo 1 || echo 0)"
eq "a failure does not stop the later scripts" 1 "$(grep -c 'test-c.sh: last line' "$tmp/first.out")"
eq "the step prints each script's name" 3 "$(grep -c '^== scripts/test-' "$tmp/allpass.out")"
has "the step prints each script's last line" 'test-b.sh: last line' "$tmp/allpass.out"
has "the step names the failed script" 'FAILED: scripts/test-b.sh' "$tmp/middle.out"

echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
