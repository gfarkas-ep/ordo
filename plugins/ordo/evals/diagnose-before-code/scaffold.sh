#!/bin/sh
# A tiny node project with a discount bug (a percent is subtracted as an amount), a passing test and a shell
# test runner, so the diagnose skill has a real bug report to work on. No package manager.
# Writes only under the run's working directory.
set -e
# Safety: refuse when HOME is the account's real home (physical paths compared), so a run can never write into it.
real=$(cd "$(eval echo "~$(id -un)")" 2>/dev/null && pwd -P) || { echo "scaffold: refusing: cannot resolve the real home" >&2; exit 1; }
mine=$(cd "${HOME:-/nonexistent}" 2>/dev/null && pwd -P) || { echo "scaffold: refusing: HOME is not a folder" >&2; exit 1; }
[ "$mine" != "$real" ] && [ "$(pwd -P)" != "$real" ] || { echo "scaffold: refusing: HOME is the real home" >&2; exit 1; }

cat > price.js <<'MD'
function applyDiscount(total, percent) {
  return total - percent;
}

function checkout(items, percent) {
  const total = items.reduce((sum, item) => sum + item.price * item.qty, 0);
  return applyDiscount(total, percent);
}

module.exports = { applyDiscount, checkout };
MD

cat > price.test.js <<'MD'
const assert = require("assert");
const { checkout } = require("./price");

assert.strictEqual(checkout([{ price: 100, qty: 2 }], 0), 200);
console.log("ok 1 passed");
MD

cat > test.sh <<'MD'
#!/bin/sh
node price.test.js
MD
chmod +x test.sh
