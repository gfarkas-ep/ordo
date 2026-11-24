#!/bin/sh
# A tiny node project whose tests pass while one acceptance criterion of SPEC.md is not met (slugify leaves a
# leading and trailing hyphen), so the qa agent has a real defect to find. No git repo, no package manager.
# Writes only under the run's working directory.
set -e
# Safety: refuse when HOME is the account's real home (physical paths compared), so a run can never write into it.
real=$(cd "$(eval echo "~$(id -un)")" 2>/dev/null && pwd -P) || { echo "scaffold: refusing: cannot resolve the real home" >&2; exit 1; }
mine=$(cd "${HOME:-/nonexistent}" 2>/dev/null && pwd -P) || { echo "scaffold: refusing: HOME is not a folder" >&2; exit 1; }
[ "$mine" != "$real" ] && [ "$(pwd -P)" != "$real" ] || { echo "scaffold: refusing: HOME is the real home" >&2; exit 1; }

cat > slug.js <<'MD'
function slugify(text) {
  return text.toLowerCase().replace(/\s+/g, "-");
}

module.exports = { slugify };
MD

cat > slug.test.js <<'MD'
const assert = require("assert");
const { slugify } = require("./slug");

let passed = 0;

function check(label, actual, expected) {
  assert.strictEqual(actual, expected, `${label}: got ${actual}, expected ${expected}`);
  passed += 1;
}

check("lowercase and hyphen", slugify("Hello World"), "hello-world");
check("runs of spaces collapse", slugify("a   b"), "a-b");

console.log(`ok ${passed} passed`);
MD

cat > test.sh <<'MD'
#!/bin/sh
node slug.test.js
MD
chmod +x test.sh

cat > SPEC.md <<'MD'
# slugify

`slugify(text)` in `slug.js` turns a title into a URL slug.

Acceptance criteria:

1. AC1: `slugify("Hello World")` returns `hello-world`.
2. AC2: a run of spaces becomes one hyphen: `slugify("a   b")` returns `a-b`.
3. AC3: leading and trailing whitespace is dropped, so a slug never starts or ends with a hyphen: `slugify("  Hello World  ")` returns `hello-world`.
MD
