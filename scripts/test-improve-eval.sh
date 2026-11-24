#!/bin/bash
# Tests for plugins/ordo/skills/improve/improve-eval.sh. Free: temp HOME and temp project folders only (never the real ~/.claude), a fake `claude` on PATH that records its arguments, no network, no model.
# Seam: script args + temp HOME/project -> stdout, stderr, exit code, files under the temp roots. Misses real eval behaviour (the paid probe T0 covers that).
set -u

root=$(cd "$(dirname "$0")/.." && pwd)
S=${IMPROVE_EVAL:-$root/plugins/ordo/skills/improve/improve-eval.sh}
tmp_root=${TMPDIR:-/tmp}
tmp_root=${tmp_root%/}
work=$(mktemp -d "$tmp_root/improve-test.XXXXXX")
cleanup() {
  if [ -n "${work:-}" ] && [ -d "$work" ] && [ "${work#"$tmp_root"/}" != "$work" ]; then
    rm -r "$work"
  fi
}
trap cleanup EXIT

pass=0; fail=0
ok() { echo "ok   - $1"; pass=$((pass + 1)); }
bad() { echo "FAIL - $1"; fail=$((fail + 1)); }
eq() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected [$2], got [$3])"; fi; }
has() { if printf '%s\n' "$3" | grep -Fq -- "$2"; then ok "$1"; else bad "$1 ([$2] not in [$3])"; fi; }
hasnt() { if printf '%s\n' "$3" | grep -Fq -- "$2"; then bad "$1 ([$2] in [$3])"; else ok "$1"; fi; }

# Fake claude: records its arguments one per line, copies the temp plugin copy it was given, writes the --json file.
mkdir -p "$work/bin"
cat > "$work/bin/claude" <<'FAKE'
#!/bin/sh
printf '%s\n' "$@" > "$FAKE_LOG.args"
echo "$HOME" > "$FAKE_LOG.home"
pwd > "$FAKE_LOG.cwd"
copy=$3
echo "$copy" > "$FAKE_LOG.copy"
rm -rf "$FAKE_LOG.tree"; cp -R "$copy" "$FAKE_LOG.tree"
[ -n "$FAKE_NOJSON" ] || while [ $# -gt 0 ]; do [ "$1" = --json ] && { if [ -n "$FAKE_RESULTS" ]; then cp "$FAKE_RESULTS" "$2"; else printf '[]\n' > "$2"; fi; }; shift; done
exit "${FAKE_RC:-0}"
FAKE
chmod +x "$work/bin/claude"

# newenv <name>: fresh temp HOME and project; sets h, p, out, err, rc
n=0
newenv() { n=$((n + 1)); h=$work/e$n/home; p=$work/e$n/proj; mkdir -p "$h" "$p"; }
# run <args...>: in the project folder with the temp HOME and the fake claude first on PATH
run() {
  out=$( cd "$p" && HOME=$h PATH="$work/bin:$PATH" FAKE_LOG=$work/e$n/fake FAKE_RC=${FAKE_RC:-0} FAKE_NOJSON=${FAKE_NOJSON:-} FAKE_RESULTS=${FAKE_RESULTS:-} sh "$S" "$@" 2>"$work/err" ); rc=$?
  err=$(cat "$work/err")
}

# a mini plugin tree, so the copy, the results exclusion and the case lookup are tested without the real plugin
mp=$work/mp
mkdir -p "$mp/skills/improve" "$mp/skills/dev" "$mp/agents" "$mp/evals/plug-a/graders" "$mp/evals/plug-b/graders" "$mp/evals/results" "$mp/evals-noagent" "$mp/evals/plug-c/graders" "$mp/evals/plug-d/graders"
cp "$S" "$mp/skills/improve/improve-eval.sh"
echo "skill dev" > "$mp/skills/dev/SKILL.md"; echo "agent" > "$mp/agents/dev.md"; echo old > "$mp/evals/results/old.json"
printf -- '---\nname: plug-a\nruns: 3\n---\n\nplug a prompt\n' > "$mp/evals/plug-a/prompt.md"
printf 'schema_version: "1.0"\ncontext:\n  scaffold_script: scaffold.sh\n' > "$mp/evals/plug-a/case.yaml"
printf '#!/bin/sh\necho plug-a-scaffold > plug-a.marker\n' > "$mp/evals/plug-a/scaffold.sh"; chmod +x "$mp/evals/plug-a/scaffold.sh"
echo g > "$mp/evals/plug-a/graders/g.md"
printf -- '---\nname: plug-b\n---\n\nplug b prompt\n' > "$mp/evals/plug-b/prompt.md"
echo g > "$mp/evals/plug-b/graders/g.md"
printf -- '---\nname: plug-c\ntags: [worth-it]\n---\n\nplug c prompt\n' > "$mp/evals/plug-c/prompt.md"
printf -- '---\nname: plug-d\ntags: [bash-skills]\n---\n\nplug d prompt\n' > "$mp/evals/plug-d/prompt.md"
echo g > "$mp/evals/plug-c/graders/g.md"; echo g > "$mp/evals/plug-d/graders/g.md"
MS=$mp/skills/improve/improve-eval.sh

# ---- scope and limit ----
newenv
run scope --project-dir "$p"
eq "scope default: global and its root" "scope: global
root: $h/.claude" "$out"
run limit --project-dir "$p"
eq "limit default 40" 40 "$out"

newenv
mkdir -p "$h/.claude"
printf 'ordo addon_scope: project\nordo addon_max_lines: 12\n' > "$h/.claude/CLAUDE.md"
run scope --project-dir "$p"
eq "scope from the global CLAUDE.md, project root" "scope: project
root: $p/.claude" "$out"
run limit --project-dir "$p"
eq "limit from the global CLAUDE.md" 12 "$out"
printf 'ordo addon_scope: global\nordo addon_max_lines: 7\n' > "$p/CLAUDE.md"
run scope --project-dir "$p"
eq "project scope line beats global" "scope: global
root: $h/.claude" "$out"
run limit --project-dir "$p"
eq "project limit beats global" 7 "$out"
printf 'ordo addon_scope: bogus\nordo addon_max_lines: 0\n' > "$p/CLAUDE.md"
run scope --project-dir "$p"
eq "invalid project scope ignored, global level applies" "scope: project
root: $p/.claude" "$out"
run limit --project-dir "$p"
eq "invalid project limit ignored, global level applies" 12 "$out"
printf 'ordo addon_scope: ask\nordo addon_max_lines: 3x\n  ordo addon_max_lines: 009  \r\nordo addon_max_lines: -4\n' > "$p/CLAUDE.md"
run scope --project-dir "$p"
eq "scope ask prints no root" "scope: ask" "$out"
run limit --project-dir "$p"
eq "last valid limit line wins, padding and CR allowed, leading zeros dropped" 9 "$out"


# ---- write ----
newenv
printf -- '- rule one\n- rule two\n' > "$work/e$n/cand.md"
cand=$work/e$n/cand.md
W() { run write --root "$1" --name "${2:-dev}" --from "${3:-$cand}" --lesson "${4:-lesson text}" --result "${5:-3/3}" --project-dir "$p"; }
addon_g=$h/.claude/ordo/addons/dev.md

W "$h/.claude" dev
eq "write to the global root: exit 0" 0 "$rc"
eq "write puts the candidate in place" "$(cat "$cand")" "$(cat "$addon_g" 2>/dev/null)"
eq "first write: no add-on file left besides dev.md and history" "dev.md|history" "$(ls "$h/.claude/ordo/addons" | paste -sd'|' -)"
hist1=$(ls "$h/.claude/ordo/addons/history" | head -1)
case $hist1 in dev-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]*.md) ok "history name is <name>-YYYYMMDD-HHMMSS.md";; *) bad "history name [$hist1]";; esac
hbody=$(cat "$h/.claude/ordo/addons/history/$hist1")
has "no previous add-on record" "no previous add-on" "$hbody"
has "record carries the lesson" "lesson text" "$hbody"
has "record carries the result" "3/3" "$hbody"

printf -- '- new rule\n' > "$work/e$n/cand2.md"
W "$h/.claude" dev "$work/e$n/cand2.md" "second lesson" "not verified"
eq "second write replaces the add-on" "- new rule" "$(cat "$addon_g")"
eq "two writes leave two history files" 2 "$(ls "$h/.claude/ordo/addons/history" | wc -l | tr -d ' ')"
old=$(grep -l -F -- '- rule two' "$h/.claude/ordo/addons/history"/* | head -1)
[ -n "$old" ] && ok "old content saved in history before it was replaced" || bad "old content missing from history"
has "history of the replaced add-on carries the new lesson" "second lesson" "$(cat "$old")"
has "history carries 'not verified'" "not verified" "$(cat "$old")"

# same second: a fake date gives every write the same time
mkdir -p "$work/fakedate"
printf '#!/bin/sh\necho 20260101-120000\n' > "$work/fakedate/date"; chmod +x "$work/fakedate/date"
newenv
printf -- '- a\n' > "$work/e$n/c1.md"; printf -- '- b\n' > "$work/e$n/c2.md"; printf -- '- c\n' > "$work/e$n/c3.md"
PATH="$work/fakedate:$PATH"
W "$h/.claude" dev "$work/e$n/c1.md"; W "$h/.claude" dev "$work/e$n/c2.md"; W "$h/.claude" dev "$work/e$n/c3.md"
PATH=${PATH#"$work/fakedate:"}
eq "three writes in one second give three history files" 3 "$(ls "$h/.claude/ordo/addons/history" | wc -l | tr -d ' ')"
eq "same-second history names" "dev-20260101-120000-02.md|dev-20260101-120000-03.md|dev-20260101-120000.md" "$(ls "$h/.claude/ordo/addons/history" | paste -sd'|' -)"

# project root
newenv
printf -- '- p\n' > "$work/e$n/c.md"
W "$p/.claude" ba "$work/e$n/c.md"
eq "write to the project root" "- p" "$(cat "$p/.claude/ordo/addons/ba.md")"
eq "an agent name is accepted and nothing went to the global root" "" "$(ls "$h/.claude" 2>/dev/null)"

# refusals: each exits 1 with one improve-eval line, writes nothing
refuse() { # name want-fragment
  eq "$1: exit 1" 1 "$rc"
  has "$1: message" "improve-eval: " "$err"
  has "$1: names the reason" "$2" "$err"
  eq "$1: one stderr line" 1 "$(printf '%s\n' "$err" | wc -l | tr -d ' ')"
}
newenv; printf -- '- x\n' > "$work/e$n/c.md"; c=$work/e$n/c.md
mkdir -p "$work/e$n/other"
W "$work/e$n/other" dev "$c"; refuse "root outside the two" "root"
eq "root outside the two: nothing written" "" "$(ls "$work/e$n/other")"
W "$h/.claude/plugins/cache/x" dev "$c"; refuse "path into plugins/" "root"
W "$h/.claude/" dev "$c"; eq "trailing slash on the root is the same root" 0 "$rc"
newenv; printf -- '- x\n' > "$work/e$n/c.md"; c=$work/e$n/c.md
mkdir -p "$h/.claude/plugins/proj"
run write --root "$h/.claude/plugins/proj/.claude" --name dev --from "$c" --lesson l --result r --project-dir "$h/.claude/plugins/proj"
refuse "project folder inside ~/.claude/plugins" "plugins"
eq "no file written into plugins" "" "$(find "$h/.claude/plugins/proj" -type f)"
# the plugin's own folder and the symlink cases run against the mini plugin only, with its own copy of the script
plug=$mp
SAVE_S=$S; S=$MS
run write --root "$plug/.claude" --name dev --from "$c" --lesson l --result r --project-dir "$plug"
refuse "project folder is the plugin's own folder" "plugin"
[ ! -e "$plug/.claude" ] && ok "plugin folder untouched" || bad "plugin folder got a .claude"
mkdir -p "$p/.claude/ordo"; ln -s "$plug/skills" "$p/.claude/ordo/addons"
W "$p/.claude" dev "$c"; refuse "addons folder is a symlink into the plugin" "symlink"
eq "symlinked addons folder: the plugin's skills folder is untouched" "dev|improve" "$(ls "$plug/skills" | paste -sd'|' -)"
rm "$p/.claude/ordo/addons"
mkdir -p "$p/.claude/ordo/addons"; mkdir -p "$work/e$n/elsewhere"; ln -s "$work/e$n/elsewhere" "$p/.claude/ordo/addons/history"
W "$p/.claude" dev "$c"; refuse "history folder is a symlink" "symlink"
eq "symlinked history folder: nothing written through it" "" "$(ls "$work/e$n/elsewhere")"
rm "$p/.claude/ordo/addons/history"; rmdir "$p/.claude/ordo/addons" "$p/.claude/ordo"; ln -s "$work/e$n/elsewhere" "$p/.claude/ordo"
W "$p/.claude" dev "$c"; refuse ".claude/ordo is a symlink" "symlink"
rm "$p/.claude/ordo"
# a planted symlink at the add-on file name: refused, its target untouched
mkdir -p "$p/.claude/ordo/addons"; echo base > "$work/e$n/skill.md"; ln -s "$work/e$n/skill.md" "$p/.claude/ordo/addons/dev.md"
W "$p/.claude" dev "$c"; refuse "add-on file is a symlink" "symlink"
eq "symlinked add-on file: target untouched" "base" "$(cat "$work/e$n/skill.md")"
rm "$p/.claude/ordo/addons/dev.md"
# planted predictable temp names are not followed: a wrapper plants links named for its own PID, then exec's the script (exec keeps the PID)
# so a temp name built from $$ would be hit; the stand-in target must stay untouched
out=$( cd "$p" && HOME=$h PLANT=$p/.claude/ordo/addons TARGET=$work/e$n/skill.md SCRIPT=$S CAND=$c PD=$p sh -c '
  i=0; while [ $i -le 5 ]; do ln -s "$TARGET" "$PLANT/.dev.md.$(($$ + i))"; i=$((i + 1)); done
  exec sh "$SCRIPT" write --root "$PD/.claude" --name dev --from "$CAND" --lesson l --result r --project-dir "$PD"' 2>"$work/err" ); rc=$?
eq "planted PID-named temp links: write ok, target untouched" "0|base" "$rc|$(cat "$work/e$n/skill.md")"
[ -f "$p/.claude/ordo/addons/dev.md" ] && [ ! -L "$p/.claude/ordo/addons/dev.md" ] && ok "dev.md is a regular file after the write" || bad "dev.md missing or a symlink"
rm -rf "$p/.claude"
# ~/.claude itself a symlink into the plugin: the physical path is checked, before and after mkdir
rm -rf "$h/.claude"; ln -s "$plug/agents" "$h/.claude"
W "$h/.claude" dev "$c"; refuse "~/.claude symlinked into the plugin" "plugin"
eq "~/.claude symlinked into the plugin: plugin untouched" "dev.md" "$(ls "$plug/agents")"
rm "$h/.claude"
S=$SAVE_S
# dot parts: a path with . or .. in any of the five path options is refused, also through a folder that does not exist
newenv; printf -- '- x\n' > "$work/e$n/c.md"; c=$work/e$n/c.md
mkdir -p "$h/.claude/plugins/cache/ordo"
PD=$p/nonexist/../../home/.claude/plugins/cache/ordo
run write --root "$PD/.claude" --name dev --from "$c" --lesson l --result r --project-dir "$PD"
refuse "dot-dot through a missing folder in --project-dir" ".."
eq "dot-dot repro: nothing written into plugins" "" "$(find "$h/.claude/plugins" -type f)"
run write --root "$p/./.claude" --name dev --from "$c" --lesson l --result r --project-dir "$p"; refuse "dot part in --root" "--root"
run write --root "$p/.claude" --name dev --from "$p/../x" --lesson l --result r --project-dir "$p"; refuse "dot-dot in --from" "--from"
run write --root "$p/.claude" --name dev --from "$c" --lesson l --result r --project-dir "$p/."; refuse "dot in --project-dir" "--project-dir"
run restore --root "$p/.claude" --name dev --version ../x.md --project-dir "$p"; refuse "dot-dot in --version" "--version"
run write --root "$p/nope/.claude" --name dev --from "$c" --lesson l --result r --project-dir "$p/nope"; refuse "project folder that does not exist" "--project-dir"
eq "no folder created for a missing project dir" "" "$(ls "$p")"
newenv; printf -- '- x\n' > "$work/e$n/c.md"; c=$work/e$n/c.md
W "$h/.claude" nosuchname "$c"; refuse "unknown name" "name"
W "$h/.claude" ../dev "$c"; refuse "name with a path" "name"
W "$h/.claude" improve "$c"; refuse "name improve" "name"
W "$h/.claude" coach "$c"; refuse "name coach" "name"
W "$h/.claude" dev "$work/missing.md"; refuse "missing --from file" "FILE"
eq "refusals wrote no add-on" "" "$(find "$h/.claude" -type f 2>/dev/null)"
i=0; : > "$work/e$n/big.md"; while [ $i -lt 41 ]; do echo "- r$i" >> "$work/e$n/big.md"; i=$((i + 1)); done
W "$h/.claude" dev "$work/e$n/big.md"; refuse "41 lines over the default limit" "40"
i=0; : > "$work/e$n/ok40.md"; while [ $i -lt 40 ]; do echo "- r$i" >> "$work/e$n/ok40.md"; i=$((i + 1)); done
W "$h/.claude" dev "$work/e$n/ok40.md"; eq "40 lines are within the limit" 0 "$rc"
printf 'a\n\n\nb' > "$work/e$n/blank.md"; printf 'ordo addon_max_lines: 3\n' > "$p/CLAUDE.md"
W "$h/.claude" dev "$work/e$n/blank.md"; refuse "blank lines and an unterminated last line count" "3"
run write --root "$h/.claude" --name dev
eq "write with missing arguments is a usage error" 2 "$rc"


# ---- history and restore ----
newenv
mkdir -p "$work/fakedate2"
printf '#!/bin/sh\ncat "%s"\n' "$work/e$n/clock" > "$work/fakedate2/date"; chmod +x "$work/fakedate2/date"
tick() { echo "$1" > "$work/e$n/clock"; }
for v in one two three; do printf -- '- %s\n' "$v" > "$work/e$n/$v.md"; done
PATH="$work/fakedate2:$PATH"
tick 20260101-100000; W "$h/.claude" tdd "$work/e$n/one.md" "lesson A" "3/3"
tick 20260101-110000; W "$h/.claude" tdd "$work/e$n/two.md" "lesson B" "not verified"
tick 20260101-120000; W "$h/.claude" tdd "$work/e$n/three.md" "lesson C" "3/3"
run history --root "$h/.claude" --name tdd --project-dir "$p"
eq "history: exit 0" 0 "$rc"
eq "history lists newest first: file, lesson, result" "tdd-20260101-120000.md	lesson C	3/3
tdd-20260101-110000.md	lesson B	not verified
tdd-20260101-100000.md	lesson A	3/3" "$out"
run history --root "$h/.claude" --name ba --project-dir "$p"
eq "history of a name with no entries: empty, exit 0" "0|" "$rc|$out"

# restore the oldest real add-on version: history holds 'two' (saved when 'three' replaced it); 'one' sits in the second entry
tick 20260101-130000
run restore --root "$h/.claude" --name tdd --version "$h/.claude/ordo/addons/history/tdd-20260101-110000.md" --project-dir "$p"
eq "restore: exit 0" 0 "$rc"
eq "restore makes that version the add-on, without its header" "- one" "$(cat "$h/.claude/ordo/addons/tdd.md")"
eq "restore saved the file it replaced first" "- three" "$(sed '1,/^-->$/d' "$h/.claude/ordo/addons/history/tdd-20260101-130000.md")"
has "restore history entry names the restored version" "tdd-20260101-110000.md" "$(cat "$h/.claude/ordo/addons/history/tdd-20260101-130000.md")"
run restore --root "$h/.claude" --name tdd --version tdd-20260101-100000.md --project-dir "$p"
eq "restore of a 'no previous add-on' entry: exit 0" 0 "$rc"
[ ! -e "$h/.claude/ordo/addons/tdd.md" ] && ok "that version is 'no add-on': the file is removed" || bad "add-on file still there"
eq "the removed add-on was saved to history first" "- one" "$(sed '1,/^-->$/d' "$h/.claude/ordo/addons/history/tdd-20260101-130000-02.md")"
run restore --root "$h/.claude" --name tdd --version tdd-20260101-100000.md --project-dir "$p"
eq "restore of a 'no previous add-on' entry with no add-on present: exit 0, still no file" "0|" "$rc|$(ls "$h/.claude/ordo/addons" | grep -c '^tdd.md$' | sed 's/^0$//')"
run restore --root "$h/.claude" --name tdd --version tdd-20260101-110000.md --project-dir "$p"
eq "restore after removal brings the version back" "- one" "$(cat "$h/.claude/ordo/addons/tdd.md")"
run restore --root "$h/.claude" --name tdd --version "$work/e$n/one.md" --project-dir "$p"
eq "restore of a file outside history refused" 1 "$rc"
has "outside-history restore: message" "history" "$err"
run restore --root "$h/.claude" --name ba --version "$h/.claude/ordo/addons/history/tdd-20260101-110000.md" --project-dir "$p"
eq "restore of another name's entry refused" 1 "$rc"
run restore --root "$work" --name tdd --version x --project-dir "$p"
eq "restore: root outside the two refused" 1 "$rc"
printf 'ordo addon_max_lines: 0\nordo addon_max_lines: 1\n' > "$p/CLAUDE.md"
printf -- '- x\n- y\n' > "$h/.claude/ordo/addons/history/tdd-20260101-140000.md.body"
{ printf '<!-- ordo add-on history\nname: tdd\nsaved: 20260101-140000\nlesson: l\nresult: r\nprevious: add-on\n-->\n'; cat "$h/.claude/ordo/addons/history/tdd-20260101-140000.md.body"; } > "$h/.claude/ordo/addons/history/tdd-20260101-140000.md"
rm "$h/.claude/ordo/addons/history/tdd-20260101-140000.md.body"
run restore --root "$h/.claude" --name tdd --version tdd-20260101-140000.md --project-dir "$p"
eq "restore of a version over the limit refused" 1 "$rc"
has "over-limit restore: message" "limit" "$err"
PATH=${PATH#"$work/fakedate2:"}


# ---- run ----
S=$mp/skills/improve/improve-eval.sh

newenv
lc=$work/e$n/lesson-case; ec=$work/e$n/earlier-case
mkdir -p "$lc/graders" "$ec/graders"
printf -- '---\nname: lesson-case\nruns: 3\n---\n\nlesson prompt\n' > "$lc/prompt.md"
printf 'schema_version: "1.0"\ncontext:\n  scaffold_script: scaffold.sh\n' > "$lc/case.yaml"
printf '#!/bin/bash\nset -e\necho lesson-scaffold > lesson.marker\n' > "$lc/scaffold.sh"; chmod +x "$lc/scaffold.sh"
echo g > "$lc/graders/g.md"
printf -- '---\nname: earlier-case\ntags: [x]\n---\n\nearlier prompt\n' > "$ec/prompt.md"
echo g > "$ec/graders/g.md"
glob=$work/e$n/global.md; proj=$work/e$n/project.md
printf -- "- global rule with 'quotes', \$HOME, \`tick\`, and a line\nORDO_ADDON_EOF_1\n- last\n" > "$glob"
printf -- '- project rule\n' > "$proj"
out_dir=$h/.claude/ordo/improve/out
R() { run run "$@"; }

R --stage lesson --name dev --case "$lc" --global "$glob" --project "$proj" --runs 5 --out "$h/.claude/ordo/improve/outL"
eq "lesson run: exit 0" 0 "$rc"
ltree=$work/e$n/ltree; cp -R "$work/e$n/fake.tree" "$ltree"
R --stage regression --name dev --global "$glob" --project "$proj" --earlier "$ec" --plugin-case plug-a --plugin-case plug-b --runs 5 --out "$out_dir"
eq "run regression: exit 0" 0 "$rc"
eq "run prints the results JSON path" "$out_dir/results.json" "$out"
[ -s "$out_dir/results.json" ] && ok "results JSON exists" || bad "results JSON missing"
copy=$(cat "$work/e$n/fake.copy")
eq "claude got exactly these arguments" "plugin
eval
$copy
--eval-dir
evals-improve
--ablation
none
--no-publish
--trust-plugin
--scaffold
--output-dir
$out_dir
--json
$out_dir/results.json" "$(cat "$work/e$n/fake.args")"
case $copy in "${TMPDIR:-/tmp}"*|/tmp/*|/private/*|/var/*) ok "the copy is a temp folder";; *) bad "copy path [$copy]";; esac
tree=$work/e$n/fake.tree
eq "the copy holds the cases under evals-improve" "earlier-case|plug-a|plug-b" "$(ls "$tree/evals-improve" | paste -sd'|' -)"
[ ! -e "$tree/evals-improve/lesson-case" ] && ok "regression does not place the lesson case (AC28)" || bad "regression ran the lesson case"
eq "the copy holds the plugin files" "skill dev" "$(cat "$tree/skills/dev/SKILL.md")"
[ ! -e "$tree/evals/results" ] && ok "results are excluded from the copy" || bad "results copied"
eq "runs set on a case with a runs line" "runs: 5" "$(grep '^runs:' "$ltree/evals-improve/lesson-case/prompt.md")"
eq "runs set on a plugin case" "runs: 5" "$(grep '^runs:' "$tree/evals-improve/plug-a/prompt.md")"
eq "runs added to a case with none (inside the front matter)" "---
name: earlier-case
tags: [x]
runs: 5
---" "$(sed -n 1,5p "$tree/evals-improve/earlier-case/prompt.md")"
eq "the rest of the prompt is unchanged" "lesson prompt" "$(tail -1 "$ltree/evals-improve/lesson-case/prompt.md")"
eq "graders copied" g "$(cat "$tree/evals-improve/earlier-case/graders/g.md")"
eq "a case with no case.yaml gets one naming the scaffold" "scaffold.sh" "$(sed -n 's/^ *scaffold_script: *//p' "$tree/evals-improve/plug-b/case.yaml")"
[ ! -e "$copy" ] && ok "the temp copy is removed after the run" || bad "temp copy still there: $copy"
eq "nothing written into HOME outside ordo/improve, nothing in the project folder" "" "$(find "$h" "$p" -mindepth 1 -not -path "$h/.claude" -not -path "$h/.claude/ordo" -not -path "$h/.claude/ordo/improve*" | paste -sd'|' -)"
[ ! -e "$mp/evals-improve" ] && ok "the real plugin has no evals-improve" || bad "evals-improve written into the plugin"

# the generated scaffold: both layers, then the case's own scaffold
fh=$work/e$n/fakehome; fp=$work/e$n/fakeproj; mkdir -p "$fh" "$fp"
(cd "$fp" && HOME=$fh sh "$ltree/evals-improve/lesson-case/scaffold.sh" >"$work/e$n/sc.out" 2>&1); src=$?
eq "scaffold with a temp HOME: exit 0" 0 "$src"
eq "scaffold writes the global layer into HOME" "$(cat "$glob")" "$(cat "$fh/.claude/ordo/addons/dev.md")"
eq "scaffold writes the project layer into the project" "$(cat "$proj")" "$(cat "$fp/.claude/ordo/addons/dev.md")"
eq "scaffold then runs the case's own scaffold" "lesson-scaffold" "$(cat "$fp/lesson.marker")"
eq "the case's own shebang is kept" "#!/bin/bash" "$(sed -n 1p "$ltree/evals-improve/lesson-case/scaffold.sh")"
fp2=$work/e$n/fakeproj2; mkdir -p "$fp2"
(cd "$fp2" && HOME=$fh sh "$tree/evals-improve/plug-b/scaffold.sh" >/dev/null 2>&1)
eq "a case with no scaffold still gets both layers" "- project rule" "$(cat "$fp2/.claude/ordo/addons/dev.md")"
(cd "$fp2" && HOME=$fh sh "$tree/evals-improve/plug-a/scaffold.sh" >/dev/null 2>&1)
eq "an own-scaffold plugin case runs its scaffold" "plug-a-scaffold" "$(cat "$fp2/plug-a.marker")"
# real-home guard: the script ran with HOME=$h, so that is the real home here; the guard also knows the account's home
fp3=$work/e$n/fakeproj3; mkdir -p "$fp3"
(cd "$fp3" && HOME=$h sh "$ltree/evals-improve/lesson-case/scaffold.sh" >"$work/e$n/g.out" 2>&1); grc=$?
eq "scaffold under the real HOME refuses" 1 "$grc"
has "guard message" "real home" "$(cat "$work/e$n/g.out")"
eq "guard: nothing written in the real HOME or the project" "" "$(find "$h" "$fp3" -type f -not -path "$h/.claude/ordo/improve/*")"
# the account's own home: never run a scaffold with it (a broken guard would write into the real ~/.claude);
# check instead that the generated guard lists it as a refused home
acct=$(cd -P "$(eval "printf %s ~$(id -un)")" 2>/dev/null && pwd -P)
if [ -n "$acct" ]; then
  has "scaffold guard lists the account's own home" "'$acct'" "$(grep -F 'for _rh in' "$ltree/evals-improve/lesson-case/scaffold.sh")"
fi

# red stage: current layers only, one case, no layers given
R --stage red --name dev --case "$lc" --runs 2 --out "$h/.claude/ordo/improve/out2"
eq "red stage: exit 0" 0 "$rc"
tree=$work/e$n/fake.tree
eq "red stage copies only the lesson case" "lesson-case" "$(ls "$tree/evals-improve")"
eq "red stage sets the runs" "runs: 2" "$(grep '^runs:' "$tree/evals-improve/lesson-case/prompt.md")"
fp4=$work/e$n/fakeproj4; fh4=$work/e$n/fakehome4; mkdir -p "$fp4" "$fh4"
(cd "$fp4" && HOME=$fh4 sh "$tree/evals-improve/lesson-case/scaffold.sh" >/dev/null 2>&1)
eq "no layers given: none written, the case's scaffold still runs" "lesson-scaffold|" "$(cat "$fp4/lesson.marker")|$(ls "$fp4/.claude" 2>/dev/null; ls -A "$fh4")"
R --stage lesson --name dev --case "$lc" --project "$proj" --runs 3 --out "$h/.claude/ordo/improve/out3"
eq "lesson stage: exit 0" 0 "$rc"
(cd "$fp4" && HOME=$fh4 sh "$work/e$n/fake.tree/evals-improve/lesson-case/scaffold.sh" >/dev/null 2>&1)
eq "lesson stage with a project layer only" "- project rule" "$(cat "$fp4/.claude/ordo/addons/dev.md")"
eq "lesson stage: no global layer" "" "$(ls -A "$fh4")"

# claude fails: the copy is still removed; with no JSON the script refuses; with JSON it still prints the path (a case below full pass exits 1)
FAKE_RC=1 R --stage red --name dev --case "$lc" --runs 3 --out "$h/.claude/ordo/improve/out4"
eq "claude exit 1 with a results JSON: path printed, exit 0" "0|$h/.claude/ordo/improve/out4/results.json" "$rc|$out"
FAKE_RC=2 FAKE_NOJSON=1 R --stage red --name dev --case "$lc" --runs 3 --out "$h/.claude/ordo/improve/out5"
eq "no results JSON: exit 1" 1 "$rc"
has "no results JSON: message" "improve-eval: " "$err"
[ ! -e "$(cat "$work/e$n/fake.copy")" ] && ok "the temp copy is removed after a failed run" || bad "temp copy left after a failure"

# refusals and usage errors
chk() { eq "$1: exit" "$2" "$rc"; has "$1: message" "improve-eval: " "$err"; }
R --stage lesson --name dev --case "$lc" --earlier "$ec" --runs 3 --out "$h/.claude/ordo/improve/o"; chk "earlier cases outside regression" 2
R --stage red --name dev --case "$lc" --plugin-case plug-a --runs 3 --out "$h/.claude/ordo/improve/o"; chk "plugin case outside regression" 2
R --stage regression --name dev --case "$lc" --runs 3 --out "$h/.claude/ordo/improve/o"; chk "regression with no earlier or plugin cases" 1
R --stage regression --name dev --case "$lc" --plugin-case nosuch --runs 3 --out "$h/.claude/ordo/improve/o"; chk "unknown plugin case" 1
R --stage regression --name dev --earlier "$lc" --earlier "$lc" --runs 3 --out "$h/.claude/ordo/improve/o"; chk "the same case twice" 1
R --stage bogus --name dev --case "$lc" --runs 3 --out "$h/.claude/ordo/improve/o"; chk "unknown stage" 2
R --stage red --name dev --case "$lc" --runs 0 --out "$h/.claude/ordo/improve/o"; chk "runs 0" 2
R --stage red --name dev --case "$lc" --runs x --out "$h/.claude/ordo/improve/o"; chk "runs not a number" 2
R --stage red --name dev --case "$lc" --runs 3; chk "missing --out" 2
R --stage red --name improve --case "$lc" --runs 3 --out "$h/.claude/ordo/improve/o"; chk "name improve" 1
R --stage red --name nosuch --case "$lc" --runs 3 --out "$h/.claude/ordo/improve/o"; chk "unknown name" 1
R --stage red --name dev --case "$work/nocase" --runs 3 --out "$h/.claude/ordo/improve/o"; chk "missing case folder" 1
R --stage red --name dev --case "$lc" --global "$work/none.md" --runs 3 --out "$h/.claude/ordo/improve/o"; chk "missing global layer file" 1
ecbad=$work/e$n/bad-case; cp -R "$ec" "$ecbad"; printf 'schema_version: "1.0"\n' > "$ecbad/case.yaml"
R --stage regression --name dev --earlier "$ecbad" --runs 3 --out "$h/.claude/ordo/improve/o"; chk "case.yaml with no scaffold_script" 1
eq "refusals: no claude call after the last refusal's case" "" "$(find "$h/.claude/ordo/improve/o" -type f 2>/dev/null)"


# ---- run: grader results and regex refusal (F1, F2, F3) ----
newenv; IMP=$h/.claude/ordo/improve
rc1=$work/e$n/res-pass.json; rc2=$work/e$n/res-fail.json; rc3=$work/e$n/res-threw.json
printf '{"cases":[{"name":"lesson-case","arms":{"with":[{"graders":[{"name":"g1","passed":true,"explanation":"ok"}]}]}}]}\n' > "$rc1"
printf '{"cases":[{"name":"lesson-case","arms":{"with":[{"graders":[{"name":"g1","passed":true,"explanation":"ok"},{"name":"g2","passed":false,"explanation":"no match"}]},{"graders":[{"name":"g1","passed":true,"explanation":"ok"},{"name":"g2","passed":true,"explanation":"ok"}]},{"graders":[{"name":"g1","passed":false,"explanation":"tool not used"},{"name":"g2","passed":false,"explanation":"no match"}]}]}}]}\n' > "$rc2"
printf '{"cases":[{"name":"lesson-case","arms":{"with":[{"graders":[{"name":"g1","passed":false,"explanation":"grader threw: Invalid regular expression: unrecognized character after (?"}]},{"graders":[{"name":"g2","passed":false,"explanation":"no match"}]}]}}]}\n' > "$rc3"
FAKE_RESULTS=$rc1 R --stage red --name dev --case "$lc" --runs 1 --out "$IMP/f1"
eq "F2 all passed: stdout is the results path only, exit 0" "0|$IMP/f1/results.json" "$rc|$out"
FAKE_RESULTS=$rc2 R --stage red --name dev --case "$lc" --runs 3 --out "$IMP/f2"
eq "F2 failing graders: path first, then one fail line per failing grader per run" "0|$IMP/f2/results.json
fail lesson-case run 1 g2: no match
fail lesson-case run 3 g1: tool not used
fail lesson-case run 3 g2: no match" "$rc|$out"
FAKE_RESULTS=$rc3 R --stage red --name dev --case "$lc" --runs 2 --out "$IMP/f3"
eq "F1 grader threw: exit 3" 3 "$rc"
eq "F1 grader threw: error line on stderr names grader, case and explanation" "error: grader g1 threw in case lesson-case: grader threw: Invalid regular expression: unrecognized character after (?" "$err"
[ -s "$IMP/f3/results.json" ] && ok "F1 grader threw: results.json kept" || bad "F1 results.json missing"
eq "F1 grader threw: stdout still starts with the path" "$IMP/f3/results.json" "$(printf '%s\n' "$out" | sed -n 1p)"
has "F1 grader threw: the throwing grader is also a fail line" "fail lesson-case run 1 g1: grader threw" "$out"

# F3: an inline regex flag group is refused before claude is called; JavaScript-valid groups stay allowed
rx() { # label, regex line, want-exit
  rm -rf "$work/e$n/rx"; mkdir -p "$work/e$n/rx/graders"; cp "$lc/prompt.md" "$work/e$n/rx/prompt.md"
  printf -- '---\ntype: regex\n%s\n---\n' "$2" > "$work/e$n/rx/graders/r.md"
  rm -f "$work/e$n/fake.args"
  R --stage red --name dev --case "$work/e$n/rx" --runs 1 --out "$IMP/rx$RANDOM"
  eq "$1: exit" "$3" "$rc"
}
rx "F3 (?i) refused" "pattern: '(?i)abc'" 1
has "F3 message names the case, the grader file and flags: i" "rx" "$err"
has "F3 message names the grader file" "r.md" "$err"
has "F3 message says flags: i" "flags: i" "$err"
[ ! -e "$work/e$n/fake.args" ] && ok "F3: claude not called" || bad "F3: claude was called"
rx "F3 (?s) refused" "pattern: 'a(?s)b'" 1
rx "F3 backslash escapes in the regex" "pattern: '(?i)a\\cb\\bx'" 1
has "F3 message keeps flags: i after a \\c in the regex" "flags: i" "$err"
has "F3 message keeps the regex text verbatim" 'a\cb\bx' "$err"
rx "F3 (?P<n> refused" "pattern: '(?P<n>a)'" 1
rx "F3 input_match refused" "input_match: '(?i)x'" 1
rm -rf "$work/e$n/rx"; mkdir -p "$work/e$n/rx/graders"; cp "$lc/prompt.md" "$work/e$n/rx/prompt.md"
printf -- '---\ntype: tool_order\nbefore:\n  tool: Skill\n  input_match: '"'"'(?i)x'"'"'\nafter:\n  tool: Skill\n---\n' > "$work/e$n/rx/graders/o.md"
R --stage red --name dev --case "$work/e$n/rx" --runs 1 --out "$IMP/rxo"
eq "F3 nested tool_order input_match refused" 1 "$rc"
rx "F3 (?: allowed" "pattern: 'a(?:b|c)'" 0
rx "F3 (?= allowed" "pattern: 'a(?=b)(?!c)(?<=d)(?<!e)'" 0
rx "F3 (?<name> allowed" "pattern: '(?<name>a)'" 0
rx "F3 flags: i line allowed" "pattern: 'abc'
flags: i" 0

# A1/A2: Python-only anchors \A \Z \z are refused (JavaScript reads them as the letters); an escaped backslash before the letter and \b \d \s \S \n stay allowed
rx "A1 \\A refused" "pattern: '\\Aabc'" 1
has "A1 message names the case" "rx" "$err"
has "A1 message names the grader file" "r.md" "$err"
has "A1 message says JavaScript has no \\A" 'JavaScript has no \A/\Z/\z' "$err"
has "A1 message says ^/$ without flags: m anchor the whole text" "without a 'flags: m' line they anchor the whole text" "$err"
has "A1 message offers the lookahead" '(?![\s\S])' "$err"
[ ! -e "$work/e$n/fake.args" ] && ok "A1: claude not called" || bad "A1: claude was called"
rx "A1 \\Z refused" "pattern: 'abc\\Z'" 1
rx "A1 \\z refused after a group" "pattern: '(a|b)\\z'" 1
rx "A1 \\A in input_match refused" "input_match: 'x\\Ay'" 1
rx "A1 \\A after an escaped backslash refused" "pattern: 'a\\\\\\Ab'" 1
rx "A2 escaped backslash then A allowed" "pattern: 'a\\\\Ab'" 0
rx "A2 escaped backslash then z allowed" "pattern: 'a\\\\z'" 0
rx "A2 \\b \\d \\s \\S \\n allowed" "pattern: '\\bx\\d\\s\\S\\n'" 0
rx "A2 plain letters A Z z allowed" "pattern: 'AZz'" 0

# ---- run: where --out may point (AC33) ----
IMP=$h/.claude/ordo/improve
mkdir -p "$work/e$n/elsewhere"
R --stage red --name dev --case "$lc" --runs 1 --out "$mp/evals/out"; chk "out into the plugin's evals" 1
[ ! -e "$mp/evals/out" ] && ok "nothing created in the plugin's evals" || bad "out created in plugin evals"
R --stage red --name dev --case "$lc" --runs 1 --out "$work/e$n/elsewhere/out"; chk "out outside the two roots" 1
R --stage red --name dev --case "$lc" --runs 1 --out "$h/.claude/plugins/cache/out"; chk "out in ~/.claude/plugins" 1
R --stage red --name dev --case "$lc" --runs 1 --out "$h/.claude/ordo/addons/out"; chk "out under addons, not improve" 1
R --stage red --name dev --case "$lc" --runs 1 --out "$IMP"; chk "out is the improve folder itself" 1
R --stage red --name dev --case "$lc" --runs 1 --out "$IMP/../../plugins/x"; chk "out with .. parts" 1
R --stage red --name dev --case "$lc" --runs 1 --out relative/out; chk "relative out" 1
mkdir -p "$IMP"; ln -s "$mp/evals" "$IMP/link"
R --stage red --name dev --case "$lc" --runs 1 --out "$IMP/link/x"; chk "out through a symlink into the plugin" 1
eq "symlinked out: plugin evals untouched" "plug-a|plug-b|plug-c|plug-d|results" "$(ls "$mp/evals" | paste -sd'|' -)"
rm "$IMP/link"
mkdir -p "$IMP/used"; echo precious > "$IMP/used/results.json"
R --stage red --name dev --case "$lc" --runs 1 --out "$IMP/used"; chk "out folder that already holds results.json" 1
eq "the existing results.json is not deleted" precious "$(cat "$IMP/used/results.json")"
mkdir -p "$p/.claude"
run run --stage red --name dev --case "$lc" --runs 1 --out "$p/.claude/ordo/improve/o1" --project-dir "$p"
eq "out under the project root is allowed" "0|$p/.claude/ordo/improve/o1/results.json" "$rc|$out"

# ---- run: tool grants and the regression's plugin cases ----
R --stage lesson --name dev --case "$lc" --allow-tools Bash --allow-tools Write --runs 1 --out "$IMP/g1"
eq "--allow-tools is repeatable and passed after --scaffold" "--scaffold
--allow-tools
Bash
--allow-tools
Write
--output-dir" "$(sed -n '/^--scaffold$/,/^--output-dir$/p' "$work/e$n/fake.args")"
R --stage lesson --name dev --case "$lc" --allow-tools 'Bash;rm' --runs 1 --out "$IMP/g2"; chk "tool name that is not a plain name" 2
R --stage regression --name dev --plugin-case plug-c --runs 1 --out "$IMP/g3"; chk "plugin case needing Edit with no grant" 1
R --stage regression --name dev --plugin-case plug-c --allow-tools Edit --runs 1 --out "$IMP/g4"
eq "plugin case needing Edit with --allow-tools Edit: ok" "0" "$rc"
eq "regression with only a plugin case places only it" "plug-c" "$(ls "$work/e$n/fake.tree/evals-improve")"
R --stage regression --name dev --plugin-case plug-c --plugin-case plug-d --allow-tools Edit --runs 1 --out "$IMP/g5"; chk "plugin cases needing different grants" 1
R --stage regression --name dev --plugin-case plug-c --plugin-case plug-a --allow-tools Edit --runs 1 --out "$IMP/g6"; chk "one plugin case needs Edit, another none" 1
R --stage regression --name dev --plugin-case plug-d --allow-tools Edit --runs 1 --out "$IMP/g7"; chk "grant differs from what the plugin case needs" 1
R --stage regression --name dev --plugin-case plug-a --allow-tools Bash --runs 1 --out "$IMP/g8"; chk "grant given for plugin cases that need none" 1
R --stage regression --name dev --plugin-case plug-d --allow-tools Bash --earlier "$ec" --runs 1 --out "$IMP/g9"
eq "plugin case needing Bash with --allow-tools Bash and an earlier case: ok" "0|earlier-case|plug-d" "$rc|$(ls "$work/e$n/fake.tree/evals-improve" | paste -sd'|' -)"
R --stage regression --name dev --case "$lc" --earlier "$ec" --runs 1 --out "$IMP/g10"
eq "--case on a regression is not placed" "earlier-case" "$(ls "$work/e$n/fake.tree/evals-improve")"
R --stage red --name dev --runs 1 --out "$IMP/g11"; chk "red stage still needs --case" 2

# ---- run: paths with spaces ----
sp1=$work/e$n/My\ Proj; sp2=$work/e$n/Other\ Case
mkdir -p "$sp1/graders" "$sp2/graders"
printf -- '---\nname: sp\n---\n\nspace prompt\n' > "$sp1/prompt.md"; cp "$sp1/prompt.md" "$sp2/prompt.md"
R --stage regression --name dev --earlier "$sp1" --earlier "$sp2" --runs 1 --out "$IMP/s1"
eq "earlier cases whose paths hold spaces" "0|My Proj|Other Case" "$rc|$(ls "$work/e$n/fake.tree/evals-improve" | paste -sd'|' -)"
gl=$work/e$n/star\*; mkdir -p "$gl" "$work/e$n/starX"; cp "$sp1/prompt.md" "$gl/prompt.md"; cp "$sp1/prompt.md" "$work/e$n/starX/prompt.md"
R --stage regression --name dev --earlier "$gl" --runs 1 --out "$IMP/s2"
eq "a glob character in a path is not expanded" "0|star*" "$rc|$(ls "$work/e$n/fake.tree/evals-improve" | paste -sd'|' -)"

# ---- run: the real-home guard compares physical paths and quotes safely ----
tree=$work/e$n/fake.tree
R --stage lesson --name dev --case "$lc" --runs 1 --out "$IMP/h1"
t1=$work/e$n/h1tree; cp -R "$work/e$n/fake.tree" "$t1"
guard() { # label, HOME value
  gp=$work/e$n/gp$RANDOM; mkdir -p "$gp"
  (cd "$gp" && HOME=$2 sh "$t1/evals-improve/lesson-case/scaffold.sh" >"$work/e$n/gg.out" 2>&1); grc=$?
  eq "$1: refused, nothing written" "1|" "$grc|$(find "$gp" -type f | paste -sd'|' -)"
  has "$1: guard message" "real home" "$(cat "$work/e$n/gg.out")"
}
guard "HOME with a trailing double slash" "$h//"
guard "HOME written with /." "$h/."
ln -s "$h" "$work/e$n/homelink"
guard "HOME through a symlink" "$work/e$n/homelink"
# a real home with a single quote in its path: the script runs with it and the scaffold still parses and refuses
newenv; qh="$work/e$n/it's home"; mkdir -p "$qh"; h=$qh; p=$work/e$n/proj
R --stage lesson --name dev --case "$lc" --runs 1 --out "$h/.claude/ordo/improve/q1"
eq "run with a HOME holding a single quote: exit 0" 0 "$rc"
qt=$work/e$n/qtree; cp -R "$work/e$n/fake.tree" "$qt"
gp=$work/e$n/gpq; mkdir -p "$gp"
(cd "$gp" && HOME=$qh sh "$qt/evals-improve/lesson-case/scaffold.sh" >"$work/e$n/gq.out" 2>&1); grc=$?
eq "HOME holding a single quote: scaffold refuses cleanly" "1" "$grc"
has "quote HOME: guard message, no syntax error" "real home" "$(cat "$work/e$n/gq.out")"
mkdir -p "$work/e$n/elsewhere2"
(cd "$gp" && HOME=$work/e$n/elsewhere2 sh "$qt/evals-improve/lesson-case/scaffold.sh" >"$work/e$n/gq2.out" 2>&1); grc=$?
eq "quote HOME: another HOME still works" 0 "$grc"

# ---- settings files that are not valid UTF-8 are ignored (like usage-report.py) ----
if command -v iconv >/dev/null 2>&1; then
  newenv; printf 'ordo addon_max_lines: 5\n\377\n' > "$p/CLAUDE.md"
  run limit --project-dir "$p"
  eq "project CLAUDE.md that is not valid UTF-8 is ignored" 40 "$out"
  mkdir -p "$h/.claude"; printf 'ordo addon_max_lines: 6\n' > "$h/.claude/CLAUDE.md"
  run limit --project-dir "$p"
  eq "the next level applies when the project file is invalid" 6 "$out"
fi


# ---- the tag-to-grant table equals the one in scripts/run-eval-suite.sh (red when either drifts) ----
newenv; IMP=$h/.claude/ordo/improve
nb=0
while IFS='|' read -r bname btag bflags; do
  bg=$(printf '%s' "$bflags" | grep -o -- '--allow-tools [A-Za-z]*' | sed 's/^--allow-tools //')
  bga=; for _x in $bg; do bga="$bga --allow-tools $_x"; done
  mkdir -p "$mp/evals/tag-$btag"; printf -- '---\nname: tag-%s\ntags: [%s]\n---\n\nx\n' "$btag" "$btag" > "$mp/evals/tag-$btag/prompt.md"
  if [ -n "$bg" ]; then
    R --stage regression --name dev --plugin-case "tag-$btag" $bga --runs 1 --out "$IMP/t$nb"; eq "tag $btag: suite grants $(echo $bg) accepted" 0 "$rc"
    R --stage regression --name dev --plugin-case "tag-$btag" --runs 1 --out "$IMP/u$nb"; eq "tag $btag: no grant refused" 1 "$rc"
  else
    R --stage regression --name dev --plugin-case "tag-$btag" --runs 1 --out "$IMP/t$nb"; eq "tag $btag: the suite grants nothing, none needed" 0 "$rc"
  fi
  nb=$((nb + 1))
done <<TABLE
$(sed -n 's/^  "\([a-z-]*|[a-z-]*|[^"]*\)"$/\1/p' "$root/scripts/run-eval-suite.sh")
TABLE
eq "the suite's batch table was read (10 batches)" 10 "$nb"

echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
