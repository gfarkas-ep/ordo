#!/bin/sh
# A small node project with a shell test runner, so the dev agent has a real red-green loop
# and no package manager is needed. Writes only under the run's working directory.
set -e
# Safety: refuse when HOME is the account's real home (physical paths compared), so a run can never write into it.
real=$(cd "$(eval echo "~$(id -un)")" 2>/dev/null && pwd -P) || { echo "scaffold: refusing: cannot resolve the real home" >&2; exit 1; }
mine=$(cd "${HOME:-/nonexistent}" 2>/dev/null && pwd -P) || { echo "scaffold: refusing: HOME is not a folder" >&2; exit 1; }
[ "$mine" != "$real" ] && [ "$(pwd -P)" != "$real" ] || { echo "scaffold: refusing: HOME is the real home" >&2; exit 1; }

cat > greet.js <<'MD'
function greet(name) {
  return `Hello, ${name}!`;
}

module.exports = { greet };
MD

cat > greet.test.js <<'MD'
const assert = require("assert");
const { greet } = require("./greet");

let passed = 0;

function check(label, actual, expected) {
  assert.strictEqual(actual, expected, `${label}: got ${actual}, expected ${expected}`);
  passed += 1;
}

check("plain greeting", greet("ada"), "Hello, ada!");

console.log(`ok ${passed} passed`);
MD

cat > test.sh <<'MD'
#!/bin/sh
node greet.test.js
MD
chmod +x test.sh
