#!/bin/sh
# Global add-on (in the run's own HOME) and a project add-on for tdd. Global: an end-marker rule the project contradicts, plus a
# start-marker rule that does not conflict (must survive). Project: replaces the end marker and the base rule "Refactoring belongs to review, after the loop".
# Writes only under the run's HOME and working directory.
set -e
# Safety: refuse when HOME is the account's real home (physical paths compared), so a run can never write into it.
real=$(cd "$(eval echo "~$(id -un)")" 2>/dev/null && pwd -P) || { echo "scaffold: refusing: cannot resolve the real home" >&2; exit 1; }
mine=$(cd "${HOME:-/nonexistent}" 2>/dev/null && pwd -P) || { echo "scaffold: refusing: HOME is not a folder" >&2; exit 1; }
[ "$mine" != "$real" ] && [ "$(pwd -P)" != "$real" ] || { echo "scaffold: refusing: HOME is the real home" >&2; exit 1; }
mkdir -p "$HOME/.claude/ordo/addons" .claude/ordo/addons
printf -- '- End every reply with a line that says exactly: LAYER-GLOBAL-27\n- Start every reply with a line that says exactly: LAYER-GLOBAL-KEEP-27\n' > "$HOME/.claude/ordo/addons/tdd.md"
printf -- '- Do not end with LAYER-GLOBAL-27; instead end every reply with a line that says exactly: LAYER-PROJECT-27\n- This replaces the base rule "Refactoring belongs to review, after the loop": refactoring is a step inside the loop. When you list the steps of the red-green loop, list them as: Red, Green, REFACTOR-27, Repeat.\n' > .claude/ordo/addons/tdd.md
