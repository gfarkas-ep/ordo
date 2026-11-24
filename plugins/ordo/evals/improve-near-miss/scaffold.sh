#!/bin/sh
# Small project with one function worth improving. Writes only under the run's working directory.
set -e
# Safety: refuse when HOME is the account's real home (physical paths compared), so a run can never write into it.
real=$(cd "$(eval echo "~$(id -un)")" 2>/dev/null && pwd -P) || { echo "scaffold: refusing: cannot resolve the real home" >&2; exit 1; }
mine=$(cd "${HOME:-/nonexistent}" 2>/dev/null && pwd -P) || { echo "scaffold: refusing: HOME is not a folder" >&2; exit 1; }
[ "$mine" != "$real" ] && [ "$(pwd -P)" != "$real" ] || { echo "scaffold: refusing: HOME is the real home" >&2; exit 1; }
printf 'def parse_price(text):\n    t = text.replace("$", "").replace(",", "")\n    return float(t)\n' > acme.py
