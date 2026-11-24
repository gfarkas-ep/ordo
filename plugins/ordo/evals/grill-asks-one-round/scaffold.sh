#!/bin/sh
# A tiny project with only a README, so the grill skill has a folder to read but no code to answer from.
# The guard keeps a run from using the real home (the skill reads add-on files under HOME). Writes only under the run's working directory.
set -e
# Safety: refuse when HOME is the account's real home (physical paths compared), so a run can never write into it.
real=$(cd "$(eval echo "~$(id -un)")" 2>/dev/null && pwd -P) || { echo "scaffold: refusing: cannot resolve the real home" >&2; exit 1; }
mine=$(cd "${HOME:-/nonexistent}" 2>/dev/null && pwd -P) || { echo "scaffold: refusing: HOME is not a folder" >&2; exit 1; }
[ "$mine" != "$real" ] && [ "$(pwd -P)" != "$real" ] || { echo "scaffold: refusing: HOME is the real home" >&2; exit 1; }

cat > README.md <<'MD'
# tracker

A small issue tracker for a team of eight.
MD
