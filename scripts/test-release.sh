#!/bin/bash
# Release checks: manifests, frontmatter a parser reads, licence and credit files, leak checks, the generated rules block, issue templates. Free: reads repo files only, no model call.
set -uo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root" || exit 2
command -v jq >/dev/null 2>&1 || { echo "test-release: jq is required" >&2; exit 2; }

pass=0; fail=0
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "FAIL: $1"; }
eq()  { [ "$2" = "$3" ] && ok || bad "$1 (expected '$2', got '$3')"; }
has() { grep -qF -- "$2" "$3" && ok || bad "$1: '$2' missing in $3"; }


plugin=plugins/ordo/.claude-plugin/plugin.json
market=.claude-plugin/marketplace.json

# --- manifests: version, strict-YAML frontmatter ---
eq "plugin.json version" 0.16.0 "$(jq -r .version "$plugin" 2>/dev/null)"
# frontmatter must be strict YAML (GitHub's renderer and other tools reject it otherwise):
# no unquoted ": " in a plain value, no unquoted ":" inside a [flow, list]
for f in plugins/ordo/skills/*/SKILL.md plugins/ordo/agents/*.md; do
  msg=$(awk 'NR==1 && $0!="---" {exit} NR>1 && $0=="---" {exit}
    NR>1 && match($0, /^[a-z_-]+: /) { v=substr($0, RLENGTH+1)
      if (v ~ /^["\047]/) next
      if (v ~ /^\[/) { n=split(substr(v,2,length(v)-2), it, ","); for (i=1;i<=n;i++) { x=it[i]; gsub(/^ +| +$/,"",x); if (x !~ /^["\047]/ && x ~ /:/) print "unquoted : in flow list item " x } }
      else if (v ~ /: /) print "unquoted : in value of " substr($0,1,RLENGTH-2) }' "$f")
  [ -z "$msg" ] && ok || bad "frontmatter of $f: $msg"
done
eq "marketplace.json plugin entry has no version key (plugin.json is the only version)" false "$(jq -r '.plugins[0] | has("version")' "$market" 2>/dev/null)"

icon=plugins/ordo/.claude-plugin/icon.png
eq "listing icon is a 1024 x 1024 PNG under 2 MB" "PNG 1024 1024 small" "$(python3 - "$icon" <<'PY' 2>/dev/null
import struct,sys,os
p=sys.argv[1]; b=open(p,'rb').read(24)
w,h=struct.unpack('>II',b[16:24]) if b[:8]==b'\x89PNG\r\n\x1a\n' else (0,0)
print('PNG' if b[:4]==b'\x89PNG' else 'not-png', w, h, 'small' if os.path.getsize(p)<2*1024*1024 else 'big')
PY
)"

# --- frontmatter keys Claude Code reads: name equals the folder or file name, description is non-empty (key presence only, never wording; `claude plugin validate` only warns on a missing description) ---
fm_check() { # file expected-name: prints a reason, returns 1 when name or description is wrong inside the frontmatter
  awk -v want="$2" 'NR==1 && $0!="---" {exit} NR>1 && $0=="---" {exit}
    NR>1 && $0 == "name: " want {n=1}
    NR>1 && /^description:[ \t]*[^ \t]/ {d=1}
    END { if (!n) print "no `name: " want "` in the frontmatter"; if (!d) print "no non-empty `description:` in the frontmatter" }' "$1"
}
for f in plugins/ordo/skills/*/SKILL.md; do
  msg=$(fm_check "$f" "$(basename "$(dirname "$f")")"); [ -z "$msg" ] && ok || bad "frontmatter of $f: $msg"
done
for f in plugins/ordo/agents/*.md; do
  msg=$(fm_check "$f" "$(basename "$f" .md)"); [ -z "$msg" ] && ok || bad "frontmatter of $f: $msg"
done
ph_repo='<owner''>/<repo>'
if grep -rqF -- "$ph_repo" plugins 2>/dev/null; then bad "the repo placeholder sits under plugins/ (AC44)"; else ok; fi

# --- credit comment of the adapted CLAUDE.md (legal) ---
credit='<!-- Sections 1-4 adapted from forrestchang/andrej-karpathy-skills (MIT, https://github.com/forrestchang/andrej-karpathy-skills); see LICENSE-andrej-karpathy-skills. -->'
eq "claude-md/CLAUDE.md first line is the credit comment" "$credit" "$(sed -n 1p claude-md/CLAUDE.md)"

# --- manifests ---
for f in "$plugin" "$market"; do
  jq -e . "$f" >/dev/null 2>&1 && ok || bad "$f not valid JSON"
done

# --- publisher, repository and licence files (legal; the feedback skill reads `repository`) ---
publisher=gfarkas-ep
eq "plugin.json repository (publish AC6)" 'https://github.com/gfarkas-ep/ordo' "$(jq -r .repository "$plugin" 2>/dev/null)"
eq "marketplace owner name" "$publisher" "$(jq -r .owner.name "$market" 2>/dev/null)"
eq "plugin author name" "$publisher" "$(jq -r .author.name "$plugin" 2>/dev/null)"
has "LICENSE copyright holder" "Copyright (c) 2026 $publisher" LICENSE
has "LICENSE is MIT" 'MIT License' LICENSE
has "LICENSE grants permission" 'Permission is hereby granted, free of charge' LICENSE
grep -qiE 'all rights reserved|proprietary' LICENSE && bad "'All rights reserved' or 'proprietary' left in LICENSE" || ok
[ -f claude-md/LICENSE-andrej-karpathy-skills ] && ok || bad "claude-md/LICENSE-andrej-karpathy-skills missing"
has "karpathy licence is MIT" 'Permission is hereby granted, free of charge' claude-md/LICENSE-andrej-karpathy-skills
has "karpathy licence copyright" 'Copyright (c) the andrej-karpathy-skills authors' claude-md/LICENSE-andrej-karpathy-skills
eq "plugin.json license" MIT "$(jq -r .license "$plugin" 2>/dev/null)"
for sk in tdd diagnose grill; do
  l=plugins/ordo/skills/$sk/LICENSE
  has "$sk LICENSE copyright" 'Copyright (c) 2026 Matt Pocock' "$l"
  has "$sk LICENSE permission" 'Permission is hereby granted, free of charge' "$l"
  has "$sk Adapted from line" 'Adapted from mattpocock/skills' plugins/ordo/skills/$sk/SKILL.md
done

# --- lighter-defaults T2: one source for the "Findings and rounds" block (AC29, AC31-AC33, A8) ---
src=shared/findings-and-rounds.md
begin='<!-- BEGIN findings-and-rounds (generated by scripts/sync-rules-block.sh from shared/findings-and-rounds.md; edit the source) -->'
end='<!-- END findings-and-rounds -->'
block_of() { awk -v b="$begin" -v e="$end" '$0==e{p=0} p{print} $0==b{p=1}' "$1"; }
# check_copy <agent file> <source>: prints "<file>: reason" and returns 1 when the copy is not exactly the source
check_copy() {
  local f=$1 s=$2 nb ne got
  nb=$(grep -cxF -- "$begin" "$f"); ne=$(grep -cxF -- "$end" "$f")
  if [ "$nb" != 1 ] || [ "$ne" != 1 ]; then echo "$f: expected exactly one marker pair, found $nb begin and $ne end"; return 1; fi
  got=$(block_of "$f")
  if [ -z "$got" ]; then echo "$f: block between markers is empty"; return 1; fi
  if ! block_of "$f" | cmp -s - "$s"; then echo "$f: block differs from $s"; return 1; fi
}
[ -s "$src" ] && ok || bad "$src missing or empty"
for a in code-reviewer qa po; do
  msg=$(check_copy "plugins/ordo/agents/$a.md" "$src") && ok || bad "rules block copy: $msg"
done
# negative test: a copy with one character changed, and a copy with a marker missing, must fail and name the file
tmpd=$(mktemp -d)
cp plugins/ordo/agents/qa.md "$tmpd/changed.md"; cp plugins/ordo/agents/qa.md "$tmpd/nomarker.md"
sed '/^- Tag every finding/s/exactly one/exactly onE/' "$tmpd/changed.md" > "$tmpd/c2" && mv "$tmpd/c2" "$tmpd/changed.md"
grep -vxF -- "$end" "$tmpd/nomarker.md" > "$tmpd/n2"; mv "$tmpd/n2" "$tmpd/nomarker.md"
cp plugins/ordo/agents/qa.md "$tmpd/blank.md"
awk -v e="$end" '$0==e{print ""} {print}' "$tmpd/blank.md" > "$tmpd/b2" && mv "$tmpd/b2" "$tmpd/blank.md"
for n in changed nomarker blank; do
  if msg=$(check_copy "$tmpd/$n.md" "$src"); then bad "block check passes a copy that is $n"; else
    case "$n:$msg" in "changed:$tmpd/changed.md: block differs"*|"nomarker:$tmpd/nomarker.md: expected exactly one marker pair"*|"blank:$tmpd/blank.md: block differs"*) ok;; *) bad "block check failure does not name the file for the right reason ($n): $msg";; esac
  fi
done
# sync script: END before BEGIN must be refused and leave the file byte-identical
cp plugins/ordo/agents/qa.md "$tmpd/swapped.md"
awk -v b="$begin" -v e="$end" '$0==b{hb=$0; next} $0==e{print; print hb; next} {print}' "$tmpd/swapped.md" > "$tmpd/s2" && mv "$tmpd/s2" "$tmpd/swapped.md"
cp "$tmpd/swapped.md" "$tmpd/swapped.orig"
if bash scripts/sync-rules-block.sh "$tmpd/swapped.md" >/dev/null 2>&1; then bad "sync accepts END before BEGIN"; else ok; fi
cmp -s "$tmpd/swapped.md" "$tmpd/swapped.orig" && ok || bad "sync changed a file with END before BEGIN"
rm -rf "$tmpd"

# --- community files GitHub reads, issue templates (GitHub silently drops a template that does not parse) ---
for f in CONTRIBUTING.md SECURITY.md SUPPORT.md .github/ISSUE_TEMPLATE/bug_report.yml .github/ISSUE_TEMPLATE/feature_request.yml; do
  [ -f "$f" ] && ok || bad "$f missing"
done
for t in bug_report feature_request; do
  has "$t template front matter" 'name: ' ".github/ISSUE_TEMPLATE/$t.yml"
  has "$t template body" 'body:' ".github/ISSUE_TEMPLATE/$t.yml"
done
if command -v ruby >/dev/null 2>&1; then
  for y in .github/ISSUE_TEMPLATE/*.yml; do
    ruby -ryaml -e 'YAML.load_file(ARGV[0])' "$y" >/dev/null 2>&1 && ok || bad "$y is not valid YAML"
  done
else
  echo "note: ruby missing, YAML parse of issue templates skipped"
fi
# the e-mail pattern: whole addresses are extracted and compared; with allow=1 only the exact maintainer noreply address passes (publish AC22), and only CONTRIBUTING.md gets allow=1
noreply='359341123+gfarkas-ep''@users.noreply.github.com'   # the only address CONTRIBUTING may hold; built in two parts
email_hit() { # file allow(0|1)
  local found
  found=$(grep -oiE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[a-z]{2,}' "$1")
  [ "$2" = 1 ] && found=$(printf '%s\n' "$found" | grep -vxF -- "$noreply")
  [ -n "$found" ]
}
etmp=$(mktemp)
printf 'x `%s>` y\n' "$noreply" > "$etmp"; email_hit "$etmp" 1 && bad "e-mail check flags the exact noreply address in CONTRIBUTING" || ok
printf 'x %s. y\n' "$noreply" > "$etmp"; email_hit "$etmp" 1 && bad "e-mail check flags the exact noreply address before a full stop" || ok
printf 'x %s y\n' "$noreply" > "$etmp"; email_hit "$etmp" 0 && ok || bad "e-mail check lets the noreply address through outside CONTRIBUTING"
printf 'x 1%s y\n' "$noreply" > "$etmp"; email_hit "$etmp" 1 && ok || bad "e-mail check lets 1<noreply> through"
printf 'x jo.%s y\n' "$noreply" > "$etmp"; email_hit "$etmp" 1 && ok || bad "e-mail check lets jo.<noreply> through"
printf 'x %s.evil.org y\n' "$noreply" > "$etmp"; email_hit "$etmp" 1 && ok || bad "e-mail check lets <noreply>.evil.org through"
printf 'x 1+other@users.noreply.github.com y\n' > "$etmp"; email_hit "$etmp" 1 && ok || bad "e-mail check lets a different noreply address through"
printf 'x someone@example.com y\n' > "$etmp"; email_hit "$etmp" 1 && ok || bad "e-mail check lets a private address through"
printf 'x someone@EXAMPLE.COM y\n' > "$etmp"; email_hit "$etmp" 1 && ok || bad "e-mail check lets an upper-case domain through"
rm -f "$etmp"
for f in README.md CONTRIBUTING.md SECURITY.md SUPPORT.md CHANGELOG.md .github/ISSUE_TEMPLATE/*.yml .github/pull_request_template.md .github/workflows/*; do
  allow=0; [ "$f" = CONTRIBUTING.md ] && allow=1
  email_hit "$f" "$allow" && bad "e-mail pattern in $f" || ok
done
# the repo placeholder lives only in working records, never in a shipped file (publish AC2)
if [ -e .git ]; then
  lit=$(git ls-files -z | xargs -0 grep -lF -- "$ph_repo" 2>/dev/null | grep -vE '^(docs/|ROADMAP\.md|LOW_PRIORITY\.md|LESSONS\.md)' | tr '\n' ' ')
  eq "owner/repo placeholder only in working records" "" "$lit"
else
  echo "skipped: placeholder allow-list check (not a git work tree)"
fi

# --- publish T4a: the contact address lives in CODE_OF_CONDUCT.md only ---
coc=CODE_OF_CONDUCT.md
contact='ordo.oss.project''@gmail.com'   # built in two parts so this file does not hold the address
# attribution is a licence condition of the Contributor Covenant (legal), like the Adapted-from lines above
has "CoC keeps the Contributor Covenant attribution" 'This Code of Conduct is adapted from the [Contributor Covenant][homepage], version 2.1,' "$coc"
grep -qF '[INSERT' "$coc" 2>/dev/null && bad "CoC still has an [INSERT placeholder" || ok
eq "CoC holds the contact address once" 1 "$(grep -cF -- "$contact" "$coc" 2>/dev/null)"
if [ -e .git ]; then
  eq "contact address in no tracked file but CODE_OF_CONDUCT.md (outside the working records)" "$coc" "$(git ls-files -z | xargs -0 grep -lF -- "$contact" 2>/dev/null | grep -vE '^(docs/|ROADMAP\.md|LOW_PRIORITY\.md|LESSONS\.md)' | tr '\n' ' ' | sed 's/ $//')"
else
  echo "skipped: contact address allow-list check (not a git work tree)"
fi

# --- agents and skills a program loads: files, names, exact tools lines ---
coach=plugins/ordo/agents/coach.md
[ -f "$coach" ] && ok || bad "coach agent file missing (AC21)"
imp=plugins/ordo/skills/improve/SKILL.md
[ -f "$imp" ] && ok || bad "improve skill file missing"

# the first line of each report format is read by plugins/ordo/hooks/usage_log.py: first line after each opening fence
for n in dev qa code-reviewer ba po; do
  f=plugins/ordo/agents/$n.md
  case $n in
    dev) first='Task:      <one line>';;
    qa) first='## Verdict: PASS | FAIL';;
    code-reviewer) first='## Verdict: APPROVED | CHANGES';;
    ba) first='## Spec';;
    po) first='## Value and scope|## Verdict: ACCEPTED | REJECTED | ESCALATE';;
  esac
  [ "$(awk '/^```/ {if (o) o=0; else {o=1; getline l; printf "%s%s", (c++ ? "|" : ""), l; if (l ~ /^```/) o=0}}' "$f")" = "$first" ] && ok || bad "$n: first line of a report format changed"
done
# domain skills T2b: exact tools line of every agent (AC13: Skill added to code-reviewer, ba, po only; AC12: no Write or Edit added to read-only agents)
for pair in \
  'dev|tools: Read, Write, Edit, Bash, Grep, Glob, Skill' \
  'qa|tools: Read, Grep, Glob, Bash, Skill' \
  'code-reviewer|tools: Read, Grep, Glob, Bash, Skill' \
  'ba|tools: Read, Grep, Glob, Bash, Agent, Skill' \
  'po|tools: Read, Grep, Glob, Bash, Skill' \
  'reader|tools: Read, Write, Grep, Glob' \
  'coach|tools: Read, Grep, Glob'; do
  eq "${pair%%|*} tools line is exactly '${pair#*|}' (AC12, AC13)" "${pair#*|}" "$(grep '^tools:' "plugins/ordo/agents/${pair%%|*}.md" 2>/dev/null)"
done

echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
