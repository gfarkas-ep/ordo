#!/bin/sh
# A tiny project with only a README and no CLAUDE.md (the skill's settings helper reads CLAUDE.md files
# and the usage file under HOME, so a run must never use the real home). Writes only under the run's working directory.
set -e
# Safety: refuse when HOME is the account's real home (physical paths compared), so a run can never write into it.
real=$(cd "$(eval echo "~$(id -un)")" 2>/dev/null && pwd -P) || { echo "scaffold: refusing: cannot resolve the real home" >&2; exit 1; }
mine=$(cd "${HOME:-/nonexistent}" 2>/dev/null && pwd -P) || { echo "scaffold: refusing: HOME is not a folder" >&2; exit 1; }
[ "$mine" != "$real" ] && [ "$(pwd -P)" != "$real" ] || { echo "scaffold: refusing: HOME is the real home" >&2; exit 1; }
# Safety: refuse when a GitHub token is in the environment, so a run can never file a real issue (Bash is granted to this case).
for v in GH_TOKEN GITHUB_TOKEN GH_ENTERPRISE_TOKEN; do
  eval "val=\${$v:-}"
  [ -z "$val" ] || { echo "scaffold: refusing: $v is set, a run could send a real issue" >&2; exit 1; }
done

cat > README.md <<'MD'
# demo

A small project that uses the ordo plugin.
MD
