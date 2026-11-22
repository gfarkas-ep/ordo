#!/bin/bash
# Tests for scripts/run-eval-suite.sh. No agent runs: coverage check, --dry-run and --summarize only.
# The end-to-end run (one real batch) is done by hand, see README.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
tmp_root=${TMPDIR:-/tmp}
tmp_root=${tmp_root%/}
work=$(mktemp -d "$tmp_root/suite-test.XXXXXX")
cleanup() {
  if [ -n "${work:-}" ] && [ -d "$work" ] && [ "${work#"$tmp_root"/}" != "$work" ]; then
    rm -r "$work"
  fi
}
trap cleanup EXIT

# Copy of the tree (scripts + cases, no results) so tests can add fake cases.
copy="$work/repo"
mkdir -p "$copy/scripts" "$copy/plugins/ordo"
cp "$root/scripts/run-eval-suite.sh" "$root/scripts/run-noagent-cases.sh" "$copy/scripts/"
rsync -a --exclude results "$root/plugins/ordo/evals" "$root/plugins/ordo/evals-noagent" "$copy/plugins/ordo/"
suite="$copy/scripts/run-eval-suite.sh"

fails=0
pass() { echo "ok   - $1"; }
fail() { echo "FAIL - $1"; fails=$((fails + 1)); }
# check "name" <command...>: passes when the command succeeds
check() { local n=$1; shift; if "$@"; then pass "$n"; else fail "$n"; fi; }
has() { grep -q -e "$2" <<<"$1"; }

# --- Seam 1: coverage check -------------------------------------------------
out=$(bash "$suite" --dry-run 2>&1) && rc=0 || rc=$?
check "real tree passes coverage (exit 0)" test "$rc" -eq 0

mkdir "$copy/plugins/ordo/evals/zz-fake-unassigned"
printf -- '---\nname: zz-fake-unassigned\ntags: [mystery]\n---\nx\n' > "$copy/plugins/ordo/evals/zz-fake-unassigned/prompt.md"
out=$(bash "$suite" --dry-run 2>&1) && rc=0 || rc=$?
check "unassigned case: non-zero exit" test "$rc" -ne 0
check "unassigned case: named in output" has "$out" "zz-fake-unassigned"

printf -- '---\nname: zz-fake-unassigned\ntags: [ba, po]\n---\nx\n' > "$copy/plugins/ordo/evals/zz-fake-unassigned/prompt.md"
out=$(bash "$suite" --dry-run 2>&1) && rc=0 || rc=$?
check "doubly assigned case: non-zero exit" test "$rc" -ne 0
check "doubly assigned case: named in output" has "$out" "zz-fake-unassigned"

printf -- '---\nname: zz-fake-unassigned\n---\nx\n' > "$copy/plugins/ordo/evals/zz-fake-unassigned/prompt.md"
out=$(bash "$suite" --dry-run 2>&1) && rc=0 || rc=$?
check "untagged case: non-zero exit" test "$rc" -ne 0
rm "$copy/plugins/ordo/evals/zz-fake-unassigned/prompt.md"
rmdir "$copy/plugins/ordo/evals/zz-fake-unassigned"

# --- Seam 2: --dry-run commands ---------------------------------------------
out=$(bash "$suite" --dry-run --runs 2 -j 3 2>&1) && rc=0 || rc=$?
check "dry-run exits 0" test "$rc" -eq 0
line() { grep -- "^\[$1\] " <<<"$out" || true; }
for b in ba ba-readers po trigger refine-read reader-write reader-nowrite bash-skills noagent; do
  l=$(line "$b")
  check "dry-run has a line for $b" test -n "$l"
  check "$b gets --runs 2" has "$l" "--runs 2"
  check "$b gets -j 3" has "$l" "-j 3"
  check "$b writes --json into the run folder" has "$l" "/$b.json"
done
check "ba-readers: --allow-tools Bash" has "$(line ba-readers)" "--allow-tools Bash"
check "bash-skills: --allow-tools Bash" has "$(line bash-skills)" "--allow-tools Bash"
check "reader-write: --allow-tools Write" has "$(line reader-write)" "--allow-tools Write"
check "reader-nowrite never gets Write" bash -c '! grep -q Write <<<"$1"' _ "$(line reader-nowrite)"
check "only ba-readers and bash-skills get Bash among the plugin eval batches" bash -c '! grep -E "^\[(ba|po|trigger|refine-read|reader-write|reader-nowrite)\] " <<<"$1" | grep -q "allow-tools Bash"' _ "$out"
check "noagent goes through run-noagent-cases.sh" has "$(line noagent)" "scripts/run-noagent-cases.sh"
# every real case lands in exactly one batch: count dry-run coverage by tag, and the new hook case in particular
for d in "$copy"/plugins/ordo/evals/*/; do
  n=$(grep -c . <<<"$(for t in $(sed -n 's/^tags: *\[\(.*\)\]$/\1/p' "$d/prompt.md" | tr -d ' ' | tr ',' ' '); do grep -E "^\[[^]]+\] .*--tag $t( |\$)" <<<"$out" | grep -o '^\[[^]]*\]'; done)")
  check "$(basename "$d") sits in exactly one batch" test "$n" -eq 1
done
check "hook-blocks-rebase is in batch bash-skills" has "$(line bash-skills)" "--tag bash-skills"
# README + case files: every case with a scaffold_script needs --scaffold in its batch (batch name = tag)
for d in "$copy"/plugins/ordo/evals/*/; do
  if [ -f "$d/case.yaml" ] && grep -q 'scaffold_script' "$d/case.yaml"; then
    tag=$(sed -n 's/^tags: \[\(.*\)\]$/\1/p' "$d/prompt.md")
    check "$(basename "$d") (tag $tag) batch has --scaffold" has "$(line "$tag")" "--scaffold"
  fi
done
bash "$suite" --dry-run --allow-tools Write >/dev/null 2>&1 && rc=0 || rc=$?
check "pass-through --allow-tools is refused" test "$rc" -ne 0
out=$(bash "$suite" --dry-run --batch reader-write 2>&1)
check "--batch limits the batches" bash -c '[ "$(grep -c "^\[" <<<"$1")" -eq 1 ]' _ "$out"

# --- Seam 3: summary parsing ------------------------------------------------
res="$work/results"
mkdir -p "$res"
batch_names="ba ba-readers po trigger refine-read reader-write reader-nowrite bash-skills noagent"
# case names of a batch, read from the tree (tag = batch name; noagent = evals-noagent/)
cases_of() {
  local d
  if [ "$1" = noagent ]; then
    for d in "$copy"/plugins/ordo/evals-noagent/*/; do basename "$d"; done
  else
    for d in "$copy"/plugins/ordo/evals/*/; do
      if [ -f "$d/prompt.md" ] && grep -q "^tags: \[$1\]" "$d/prompt.md"; then basename "$d"; fi
    done
  fi
}
# json_for <batch> [skip-case]: all-pass JSON, 2 runs per case
json_for() {
  local n
  for n in $(cases_of "$1"); do [ "$n" = "${2:-}" ] || echo "$n"; done | jq -R -s -c '{cases: (split("\n") | map(select(length > 0)) | map({name: ., arms: {with: [
    {passed: true, score: 1, error: null, graders: [{name: "g1", passed: true}]},
    {passed: true, score: 1, error: null, graders: [{name: "g1", passed: true}]}]}}))}'
}
for b in $batch_names; do
  json_for "$b" > "$res/$b.json"
  : > "$res/$b.log"
  echo 0 > "$res/$b.exit"
done
out=$(bash "$suite" --summarize "$res" 2>&1) && rc=0 || rc=$?
check "all-pass summary exits 0" test "$rc" -eq 0
check "all-pass summary line" has "$out" "ba-global-claude-md 2/2"

cat > "$res/po.json" <<'EOF'
{"cases":[{"name":"po-fails","arms":{"with":[
 {"passed":false,"score":0.5,"error":null,"graders":[{"name":"verdict","passed":false},{"name":"dispatch","passed":true}]},
 {"passed":true,"score":1,"error":null,"graders":[{"name":"verdict","passed":true},{"name":"dispatch","passed":true}]},
 {"passed":false,"score":0,"error":null,"graders":[{"name":"verdict","passed":false},{"name":"dispatch","passed":false}]}]}}]}
EOF
out=$(bash "$suite" --summarize "$res" 2>&1) && rc=0 || rc=$?
check "failing grader: non-zero exit" test "$rc" -ne 0
check "failing grader: case line 1/3" has "$out" "po-fails 1/3"
check "failing grader: grader names listed" has "$out" "dispatch,verdict"
check "other cases still listed" has "$out" "reader-extracts-file 2/2"

json_for po > "$res/po.json"
printf '%s\n' "x /plugins/ordo/evals/ba-x: prompt.md: invalid YAML frontmatter: YAML Parse error: Unexpected token" "1 case file(s) failed to load" > "$res/ba.log"
out=$(bash "$suite" --summarize "$res" 2>&1) && rc=0 || rc=$?
check "load failure: non-zero exit" test "$rc" -ne 0
check "load failure: invalid YAML line shown" has "$out" "invalid YAML frontmatter"
check "load failure: marked as batch error" has "$out" "BATCH ERROR"
: > "$res/ba.log"

rm "$res/reader-nowrite.json"
out=$(bash "$suite" --summarize "$res" 2>&1) && rc=0 || rc=$?
check "missing batch json: non-zero exit" test "$rc" -ne 0
check "missing batch json: batch named in error" has "$out" "BATCH ERROR.*reader-nowrite"

# --- review fixes -----------------------------------------------------------------
json_for reader-nowrite > "$res/reader-nowrite.json"; echo 0 > "$res/reader-nowrite.exit"
summ() { out=$(bash "$suite" --summarize "$res" 2>&1) && rc=0 || rc=$?; }
summ
check "baseline all-pass again" test "$rc" -eq 0

printf '{"cases":[{"name":"x","arms":{"with":[{"passed":tr' > "$res/po.json"
summ
check "truncated JSON: non-zero exit" test "$rc" -ne 0
check "truncated JSON: batch error for po" has "$out" "BATCH ERROR.*po"
check "truncated JSON: no PASS line" bash -c '! grep -q "SUITE: PASS" <<<"$1"' _ "$out"

echo '{"cases":[]}' > "$res/po.json"
summ
check "empty cases: non-zero exit" test "$rc" -ne 0
check "empty cases: missing case named" has "$out" "BATCH ERROR.*po-accepted"

json_for po po-mixed > "$res/po.json"
summ
check "one case missing: non-zero exit" test "$rc" -ne 0
check "one case missing: named" has "$out" "BATCH ERROR.*po-mixed"

json_for po > "$res/po.json"; echo 1 > "$res/po.exit"
summ
check "exit 1 but every case passed: batch error" has "$out" "BATCH ERROR.*po"
echo 0 > "$res/po.exit"

json_for noagent > "$res/noagent.json"
echo '{"cases":[]}' > "$res/noagent.json"
summ
check "noagent missing case named" has "$out" "BATCH ERROR.*ba-needs-readers"
json_for noagent > "$res/noagent.json"

rm "$res/ba.exit"
summ
check "missing .exit file: non-zero exit" test "$rc" -ne 0
check "missing .exit file: batch named" has "$out" "BATCH ERROR.*ba"
echo 0 > "$res/ba.exit"

echo "⚠ kept /private/tmp/e-K8aDSH: home/ and tmp/ in it were written by the plugin under test" > "$res/ba.log"
summ
check "harness warning line is not a batch error" test "$rc" -eq 0
: > "$res/ba.log"

bash "$suite" --dry-run --batch typo >/dev/null 2>&1 && rc=0 || rc=$?
check "--batch typo refused (dry-run)" test "$rc" -ne 0
out=$(bash "$suite" --summarize "$res" --batch typo 2>&1) && rc=0 || rc=$?
check "--batch typo refused (summarize)" test "$rc" -ne 0
check "--batch typo named" has "$out" "typo"
bash "$suite" --dry-run --batch noagent >/dev/null 2>&1 && rc=0 || rc=$?
check "--batch noagent accepted" test "$rc" -eq 0

for o in --batch --out-dir --summarize; do
  out=$(bash "$suite" "$o" 2>&1) && rc=0 || rc=$?
  check "$o without argument: usage error" test "$rc" -eq 2
  check "$o without argument: no unbound variable" bash -c '! grep -q unbound <<<"$1"' _ "$out"
done

echo
if [ "$fails" -eq 0 ]; then echo "all tests passed"; else echo "$fails test(s) failed"; exit 1; fi
