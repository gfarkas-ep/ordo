#!/bin/bash
# Runs the whole ordo eval suite in the flag batches it needs (grants differ per invocation)
# and prints one summary. Needs jq.
#
# usage: run-eval-suite.sh [--dry-run] [--out-dir DIR] [--batch NAME]... [--summarize DIR] [eval options...]
#   --dry-run        print each batch's command, run nothing
#   --out-dir DIR    run folder (default plugins/ordo/evals/results/suite-<timestamp>/, gitignored)
#   --batch NAME     run only this batch (repeatable)
#   --summarize DIR  do not run; print the summary of an existing run folder
# Other options (--runs N, -j N, --max-cost-usd ...) go to every batch. Grants (--allow-tools),
# --tag, --case, --json and --output-dir are set per batch and refused here.
# Exit 1 if any batch errored or any case is below full pass; remaining batches still run.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
plugin="$root/plugins/ordo"

# Batch table: name|tag|extra flags. A case belongs to the batch whose tag it carries.
# Flags come from the README ("Running the evals") and the cases' `# requires:` lines; a case
# with a scaffold_script in case.yaml gets --scaffold (see README note on the gaps).
batches=(
  "ba|ba|"
  "ba-readers|ba-readers|--scaffold --allow-tools Bash"
  "po|po|--scaffold"
  "trigger|trigger|--scaffold"
  "refine-read|refine-read|--scaffold"
  "reader-write|reader-write|--scaffold --allow-tools Write"
  "reader-nowrite|reader-nowrite|--scaffold"
  "bash-skills|bash-skills|--scaffold --allow-tools Bash"
)
# evals-noagent/ is its own batch ("noagent"), run only through scripts/run-noagent-cases.sh.

dry=0; out=""; only=(); summarize=""; extra=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry=1 ;;
    --out-dir|--batch|--summarize)
      [ $# -ge 2 ] || { echo "run-eval-suite: $1 needs an argument (see usage at the top of the script)" >&2; exit 2; }
      case "$1" in --out-dir) out=$2 ;; --batch) only+=("$2") ;; *) summarize=$2 ;; esac
      shift ;;
    --allow-tools|--tag|--case|--json|--output-dir|--eval-dir|--disallow-tools|--allow-tools=*|--tag=*|--case=*|--json=*|--output-dir=*)
      echo "run-eval-suite: $1 is set per batch, not passed through" >&2; exit 2 ;;
    *) extra+=("$1") ;;
  esac
  shift
done

for x in ${only[@]+"${only[@]}"}; do
  known=0; [ "$x" = noagent ] && known=1
  for b in "${batches[@]}"; do [ "${b%%|*}" = "$x" ] && known=1; done
  [ "$known" -eq 1 ] || { echo "run-eval-suite: unknown batch '$x'" >&2; exit 2; }
done

# --- coverage: every case dir in exactly one batch ---------------------------------
tags_of() { sed -n 's/^tags: *\[\(.*\)\]$/\1/p' "$1/prompt.md" | tr -d ' ' | tr ',' ' '; }
bad=0
for d in "$plugin"/evals/*/; do
  d=${d%/}
  [ -f "$d/prompt.md" ] || [ -f "$d/case.yaml" ] || continue
  name=$(basename "$d")
  hits=""
  for b in "${batches[@]}"; do
    tag=$(cut -d'|' -f2 <<<"$b")
    for t in $(tags_of "$d"); do
      [ "$t" = "$tag" ] && hits="$hits ${b%%|*}"
    done
  done
  n=$(wc -w <<<"$hits" | tr -d ' ')
  if [ "$n" -eq 0 ]; then echo "run-eval-suite: case $name is in no batch (tags: $(tags_of "$d"))" >&2; bad=1
  elif [ "$n" -gt 1 ]; then echo "run-eval-suite: case $name is in $n batches:$hits" >&2; bad=1; fi
done
[ "$bad" -eq 0 ] || exit 1

wanted() { [ ${#only[@]} -eq 0 ] && return 0; local x; for x in "${only[@]}"; do [ "$x" = "$1" ] && return 0; done; return 1; }

# case names a batch must report (from the coverage rule: tag = batch tag; noagent = evals-noagent/)
expected_cases() {
  local d t b tag
  if [ "$1" = noagent ]; then
    for d in "$plugin"/evals-noagent/*/; do d=${d%/}; { [ -f "$d/prompt.md" ] || [ -f "$d/case.yaml" ]; } && basename "$d"; done
    return 0
  fi
  for b in "${batches[@]}"; do [ "${b%%|*}" = "$1" ] && tag=$(cut -d'|' -f2 <<<"$b"); done
  for d in "$plugin"/evals/*/; do
    d=${d%/}; [ -f "$d/prompt.md" ] || continue
    for t in $(tags_of "$d"); do [ "$t" = "$tag" ] && basename "$d"; done
  done
}

# --- summary -----------------------------------------------------------------------
summary() {
  local dir=$1 b name json log rc code="" cases_bad=0 batch_bad=0
  local names=("noagent")
  for b in "${batches[@]}"; do names+=("${b%%|*}"); done
  for name in "${names[@]}"; do
    wanted "$name" || continue
    json="$dir/$name.json"; log="$dir/$name.log"; batch_cases_bad=0
    echo "-- $name"
    if [ ! -s "$json" ]; then
      echo "!!! BATCH ERROR [$name]: no result JSON ($json)"; batch_bad=$((batch_bad + 1))
    elif ! rows=$(jq -r '.cases[] | (.arms.with // []) as $r | [.name,
          ([$r[] | select(.passed and (.error == null))] | length), ($r | length),
          ([$r[].graders[]? | select(.passed | not) | .name] | unique | join(",")),
          ([$r[] | select(.error != null) | .error] | join("; "))] | @tsv' "$json" 2>&1); then
      echo "!!! BATCH ERROR [$name]: result JSON unreadable ($json): $rows"; batch_bad=$((batch_bad + 1))
    else
      seen=" "
      while IFS=$'\t' read -r cname p r graders errs; do
        [ -n "$cname" ] || continue
        seen="$seen$cname "
        echo "$cname $p/$r"
        if [ "$p" -lt "$r" ] || [ "$r" -eq 0 ]; then
          cases_bad=$((cases_bad + 1)); batch_cases_bad=$((batch_cases_bad + 1))
          [ -z "$graders" ] || echo "    failing graders: $graders"
          [ -z "$errs" ] || echo "    run errors: $errs"
        fi
      done <<<"$rows"
      for c in $(expected_cases "$name"); do
        case "$seen" in *" $c "*) ;; *) echo "!!! BATCH ERROR [$name]: case $c missing from $json"; batch_bad=$((batch_bad + 1)) ;; esac
      done
    fi
    if [ -f "$log" ]; then
      lines=$(grep -E 'invalid YAML|failed to load' "$log" || true)
      if [ -n "$lines" ]; then
        echo "!!! BATCH ERROR [$name]: load failure"; sed 's/^/    /' <<<"$lines"; batch_bad=$((batch_bad + 1))
      fi
    fi
    if [ ! -f "$dir/$name.exit" ]; then
      echo "!!! BATCH ERROR [$name]: no exit code file ($dir/$name.exit)"; batch_bad=$((batch_bad + 1))
    else
      code=$(cat "$dir/$name.exit")
      case "$code" in
        0) ;;
        1) if [ "${batch_cases_bad:-0}" -eq 0 ] && [ -s "$json" ]; then echo "!!! BATCH ERROR [$name]: harness exit 1 but no case below full pass (see $log)"; batch_bad=$((batch_bad + 1)); fi ;;
        *) echo "!!! BATCH ERROR [$name]: harness exit code $code (see $log)"; batch_bad=$((batch_bad + 1)) ;;
      esac
    fi
  done
  echo
  if [ "$cases_bad" -eq 0 ] && [ "$batch_bad" -eq 0 ]; then echo "SUITE: PASS"; return 0; fi
  echo "SUITE: FAIL ($cases_bad case(s) below full pass, $batch_bad batch error(s))"
  return 1
}

command -v jq >/dev/null || { echo "run-eval-suite: jq is required" >&2; exit 2; }
if [ -n "$summarize" ]; then summary "$summarize"; exit $?; fi

[ -n "$out" ] || out="$plugin/evals/results/suite-$(date +%Y%m%d-%H%M%S)"

# --- run ---------------------------------------------------------------------------
if [ "$dry" -eq 0 ]; then mkdir -p "$out"; fi
run_batch() { # name, then the command
  local name=$1; shift
  if [ "$dry" -eq 1 ]; then echo "[$name] $*"; return 0; fi
  echo "[$name] running..." >&2
  local rc=0
  "$@" > "$out/$name.log" 2>&1 || rc=$?
  echo "$rc" > "$out/$name.exit"
}

if wanted noagent; then
  run_batch noagent "$root/scripts/run-noagent-cases.sh" ${extra[@]+"${extra[@]}"} \
    --output-dir "$out/noagent" --json "$out/noagent.json"
fi
for b in "${batches[@]}"; do
  IFS='|' read -r name tag flags <<<"$b"
  wanted "$name" || continue
  # shellcheck disable=SC2086
  run_batch "$name" claude plugin eval "$plugin" --ablation none --no-publish --trust-plugin \
    --tag "$tag" $flags ${extra[@]+"${extra[@]}"} --output-dir "$out/$name" --json "$out/$name.json"
done

[ "$dry" -eq 1 ] && exit 0
echo "results: $out" >&2
summary "$out"
