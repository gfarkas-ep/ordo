#!/bin/sh
# A small node project in a git repo with one initial commit, plus an uncommitted change under review (a shout option on greet) that leaves a console.log debug line behind. Identity passed with git -c. Writes only under the run's working directory.
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

git init -q -b main .
git add -A
git -c user.email=t@t -c user.name=t commit -qm init

cat > greet.js <<'MD'
function greet(name, options = {}) {
  console.log("DEBUG greet", name);
  const text = `Hello, ${name}!`;
  return options.shout ? text.toUpperCase() : text;
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
check("shouted greeting", greet("ada", { shout: true }), "HELLO, ADA!");

console.log(`ok ${passed} passed`);
MD
