#!/bin/bash
# Runs plugins/ordo/evals-noagent/ against a temp copy of the plugin whose ba.md `tools:` line
# lacks Agent (AC17: the BA cannot dispatch readers). Extra args go to the eval CLI.
# Results and the HTML report go to plugins/ordo/evals-noagent/results/ in the repo unless an
# --output-dir is passed (the temp copy is deleted on exit).
# ORDO_ABLATE_FILE=<path>: use that file as ba.md in the copy (red check), before the tools rewrite.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
tmp_root=${TMPDIR:-/tmp}
tmp_root=${tmp_root%/}
work=$(mktemp -d "$tmp_root/ordo-noagent.XXXXXX")

cleanup() {
  if [ -n "${work:-}" ] && [ -d "$work" ] && [ "${work#"$tmp_root"/}" != "$work" ]; then
    rm -r "$work"
  fi
}
trap cleanup EXIT

rsync -a --exclude 'results' "$root/plugins/ordo/" "$work/ordo/"
ba="$work/ordo/agents/ba.md"

if [ -n "${ORDO_ABLATE_FILE:-}" ]; then
  cp "$ORDO_ABLATE_FILE" "$ba"
fi

sed -E '/^tools:/ s/, Agent$//' "$ba" > "$ba.new" && mv "$ba.new" "$ba"
if ! grep -q '^tools:' "$ba" || grep -E '^tools:' "$ba" | grep -q 'Agent'; then
  echo "run-noagent-cases: could not drop Agent from the tools line of ba.md" >&2
  exit 1
fi

out_args=(--output-dir "$root/plugins/ordo/evals-noagent/results")
for a in "$@"; do
  case "$a" in --output-dir|--output-dir=*) out_args=() ;; esac
done

claude plugin eval "$work/ordo" --eval-dir evals-noagent --ablation none --no-publish \
  --trust-plugin --scaffold --allow-tools Bash ${out_args[@]+"${out_args[@]}"} "$@"
