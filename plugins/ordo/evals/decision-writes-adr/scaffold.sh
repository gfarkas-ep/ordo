#!/bin/sh
# A tiny project with only a README (no docs folder, no design document), so the decision skill has to create
# docs/decisions/ itself. Writes only under the run's working directory.
set -e
# Safety: refuse when HOME is the account's real home (physical paths compared), so a run can never write into it.
real=$(cd "$(eval echo "~$(id -un)")" 2>/dev/null && pwd -P) || { echo "scaffold: refusing: cannot resolve the real home" >&2; exit 1; }
mine=$(cd "${HOME:-/nonexistent}" 2>/dev/null && pwd -P) || { echo "scaffold: refusing: HOME is not a folder" >&2; exit 1; }
[ "$mine" != "$real" ] && [ "$(pwd -P)" != "$real" ] || { echo "scaffold: refusing: HOME is the real home" >&2; exit 1; }

cat > README.md <<'MD'
# notes

A small local notes app for one person.
MD
