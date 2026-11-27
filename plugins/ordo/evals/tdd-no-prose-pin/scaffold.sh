#!/bin/sh
# A tiny sh project: slug.sh, a test runner over tests/*.sh with one behavioural test, and docs/RULES.md. Writes only under the run's working directory.
set -e
# Safety: refuse when HOME is the account's real home (physical paths compared), so a run can never write into it.
real=$(cd "$(eval echo "~$(id -un)")" 2>/dev/null && pwd -P) || { echo "scaffold: refusing: cannot resolve the real home" >&2; exit 1; }
mine=$(cd "${HOME:-/nonexistent}" 2>/dev/null && pwd -P) || { echo "scaffold: refusing: HOME is not a folder" >&2; exit 1; }
[ "$mine" != "$real" ] && [ "$(pwd -P)" != "$real" ] || { echo "scaffold: refusing: HOME is the real home" >&2; exit 1; }

mkdir -p tests docs

cat > slug.sh <<'MD'
#!/bin/sh
printf '%s\n' "$1" | tr 'A-Z ' 'a-z-'
MD

cat > tests/slug-basic.sh <<'MD'
out=$(sh slug.sh "Hello World")
[ "$out" = "hello-world" ] || { echo "slug-basic: got '$out', expected 'hello-world'"; exit 1; }
MD

cat > test.sh <<'MD'
#!/bin/sh
n=0
for t in tests/*.sh; do
  sh "$t" || { echo "FAIL $t"; exit 1; }
  n=$((n + 1))
done
echo "ok $n passed"
MD

cat > docs/RULES.md <<'MD'
# Rules

- Output is lower case.
- Spaces become hyphens.
MD
