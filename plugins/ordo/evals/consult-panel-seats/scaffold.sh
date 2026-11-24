#!/bin/sh
# A small node project with a shell test runner, a one-page spec and a ROADMAP.md with a current goal, so the
# consult-panel skill has a plan to write, a spec for the po seat and a roadmap to point at.
# Writes only under the run's working directory.
set -e
# Safety: refuse when HOME is the account's real home (physical paths compared), so a run can never write into it.
real=$(cd "$(eval echo "~$(id -un)")" 2>/dev/null && pwd -P) || { echo "scaffold: refusing: cannot resolve the real home" >&2; exit 1; }
mine=$(cd "${HOME:-/nonexistent}" 2>/dev/null && pwd -P) || { echo "scaffold: refusing: HOME is not a folder" >&2; exit 1; }
[ "$mine" != "$real" ] && [ "$(pwd -P)" != "$real" ] || { echo "scaffold: refusing: HOME is the real home" >&2; exit 1; }

mkdir -p docs/specs

cat > report.js <<'MD'
function report(rows) {
  return rows.map((r) => `${r.name}: ${r.count}`).join("\n");
}

module.exports = { report };

if (require.main === module) {
  console.log(report([{ name: "open", count: 3 }, { name: "closed", count: 5 }]));
}
MD

cat > report.test.js <<'MD'
const assert = require("assert");
const { report } = require("./report");

assert.strictEqual(report([{ name: "open", count: 3 }]), "open: 3");
console.log("ok 1 passed");
MD

cat > test.sh <<'MD'
#!/bin/sh
node report.test.js
MD
chmod +x test.sh

cat > ROADMAP.md <<'MD'
# Roadmap

## Current goal

Add a `--json` flag to `report.js` so other tools can read its output.

## Later

- Colour in the text output.
MD

cat > docs/specs/2026-11-23-report-json-flag.md <<'MD'
# Spec: --json flag for report.js

Goal: other tools can read the report as JSON.

Acceptance criteria:

1. AC1: `node report.js` prints the text report exactly as today.
2. AC2: `node report.js --json` prints a JSON array of `{"name": ..., "count": ...}` objects, one per row, and nothing else.
3. AC3: an unknown flag exits with status 2 and a one-line message on stderr.
MD
