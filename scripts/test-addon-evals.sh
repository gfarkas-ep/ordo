#!/bin/bash
# Free tests for the add-on eval cases (self-improvement loop, T6): no agent runs, no paid eval.
# Checks: case files and tags, scaffolds in a throwaway HOME, the real-home refusal, grader regexes on samples.
set -uo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
ev="$root/plugins/ordo/evals"
tmp_root=${TMPDIR:-/tmp}; tmp_root=${tmp_root%/}
work=$(mktemp -d "$tmp_root/addon-evals-test.XXXXXX")
trap '[ -n "${work:-}" ] && [ "${work#"$tmp_root"/}" != "$work" ] && rm -rf "$work"' EXIT

pass=0; fail=0
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "FAIL - $1"; }
has() { grep -qF -- "$2" "$3" 2>/dev/null && ok || bad "$1"; }
eq()  { [ "$2" = "$3" ] && ok || bad "$1 (want '$2', got '$3')"; }

cases="addon-none-silent addon-rule-followed addon-layers-override addon-cannot-loosen-git coach-refuses-out-of-scope improve-no-autostart improve-near-miss retro-dates-lesson dev-dispatch-report"

# --- case files: front matter, tag (batch), runs, graders ---------------------------------
tag_of() { sed -n 's/^tags: \[\(.*\)\]$/\1/p' "$ev/$1/prompt.md"; }
want_tag() {
  case $1 in
    addon-cannot-loosen-git) echo bash-skills ;;
    retro-dates-lesson) echo reader-write ;;
    dev-dispatch-report) echo dev-agent ;;
    *) echo trigger ;;
  esac
}
for c in $cases; do
  [ -f "$ev/$c/prompt.md" ] || { bad "$c: prompt.md missing"; continue; }
  eq "$c: name" "name: $c" "$(sed -n 's/^\(name: .*\)$/\1/p' "$ev/$c/prompt.md")"
  eq "$c: tag" "$(want_tag "$c")" "$(tag_of "$c")"
  eq "$c: runs 3" "runs: 3" "$(sed -n 's/^\(runs: .*\)$/\1/p' "$ev/$c/prompt.md")"
  n=$(find "$ev/$c/graders" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
  [ "$n" -ge 1 ] && ok || bad "$c: no graders"
done
# a case with a scaffold names it in case.yaml
for c in addon-rule-followed addon-layers-override addon-cannot-loosen-git improve-near-miss dev-dispatch-report; do
  has "$c: case.yaml names scaffold.sh" "scaffold_script: scaffold.sh" "$ev/$c/case.yaml"
done

# --- scaffolds in a throwaway HOME --------------------------------------------------------
sandbox() { # name: fresh HOME and cwd under $work
  rm -rf "$work/$1"; mkdir -p "$work/$1/home/cwd"; echo "$work/$1/home"
}
run_scaffold() { # case home -> runs the scaffold with HOME=home in home/cwd
  (cd "$2/cwd" && HOME="$2" sh "$ev/$1/scaffold.sh" >"$2/out" 2>&1); echo $?
}

h=$(sandbox c1); eq "addon-rule-followed scaffold exit" 0 "$(run_scaffold addon-rule-followed "$h")"
has "c1: project tdd add-on has the marker" "ADDON-PROJ-41" "$h/cwd/.claude/ordo/addons/tdd.md"
[ ! -e "$h/.claude" ] && ok || bad "c1: wrote a global layer it should not have"

h=$(sandbox c2); eq "addon-layers-override scaffold exit" 0 "$(run_scaffold addon-layers-override "$h")"
has "c2: global tdd add-on has the end marker" "LAYER-GLOBAL-27" "$h/.claude/ordo/addons/tdd.md"
has "c2: global tdd add-on has the non-conflicting keep marker" "LAYER-GLOBAL-KEEP-27" "$h/.claude/ordo/addons/tdd.md"
# precondition read by an eval, not a prose pin: the addon-layers-override scaffold and its base-not-kept grader depend on this sentence; if it goes, that grader passes vacuously
has "c2: tdd base still holds the rule the project add-on overrides" "Refactoring belongs to review, after the loop." "$ev/../skills/tdd/SKILL.md"
has "c2: project tdd add-on names the base-override marker" "REFACTOR-27" "$h/cwd/.claude/ordo/addons/tdd.md"
has "c2: project tdd add-on has the project marker" "LAYER-PROJECT-27" "$h/cwd/.claude/ordo/addons/tdd.md"

h=$(sandbox c3); eq "addon-cannot-loosen-git scaffold exit" 0 "$(run_scaffold addon-cannot-loosen-git "$h")"
has "c3: project workflow add-on mentions push" "push" "$h/cwd/.claude/ordo/addons/workflow.md"
eq "c3: a git repo with a commit" "1" "$(git -C "$h/cwd" rev-list --count HEAD 2>/dev/null)"
eq "c3: a bare remote named origin inside the sandbox" "true" "$(git -C "$h/cwd" ls-remote origin >/dev/null 2>&1 && git -C "$h/cwd" remote get-url origin | grep -q "^$(cd "$h/cwd" && pwd -P)/" && echo true)"
eq "c3: nothing pushed yet" "0" "$(git -C "$h/cwd" ls-remote origin 2>/dev/null | wc -l | tr -d ' ')"
eq "c3: work tree clean (remote dir not untracked)" "" "$(git -C "$h/cwd" status --porcelain 2>/dev/null)"

h=$(sandbox c5); eq "improve-near-miss scaffold exit" 0 "$(run_scaffold improve-near-miss "$h")"
[ -f "$h/cwd/acme.py" ] && ok || bad "c5: acme.py missing"

h=$(sandbox c6); eq "dev-dispatch-report scaffold exit" 0 "$(run_scaffold dev-dispatch-report "$h")"
for f in greet.js greet.test.js test.sh; do [ -f "$h/cwd/$f" ] && ok || bad "c6: $f missing"; done
eq "c6: the project's own test passes before the task" "ok 1 passed" "$(cd "$h/cwd" && sh test.sh 2>&1)"
eq "c6: nothing outside the working directory" "cwd" "$(ls -A "$h" | grep -vx out)"
eq "c6: no git repo (the brief says do not commit)" "" "$(ls -A "$h/cwd" | grep -x '\.git')"

# --- the real-home refusal: HOME is the account's real home (simulated with a PATH stub) ----
# A stub `id` makes the "real" account `nobody`, whose home is not writable, so a broken guard cannot damage anything.
nb=$(eval echo "~nobody"); nbp=$(cd "$nb" 2>/dev/null && pwd -P)
if [ -n "$nbp" ] && [ ! -w "$nbp" ]; then
  mkdir -p "$work/stub"; printf '#!/bin/sh\necho nobody\n' > "$work/stub/id"; chmod +x "$work/stub/id"
  ln -s "$nbp" "$work/homelink"
  for c in addon-rule-followed addon-layers-override addon-cannot-loosen-git improve-near-miss dev-dispatch-report; do
    for hh in "$nbp" "$work/homelink"; do
      mkdir -p "$work/guard/cwd"; rm -rf "$work/guard/cwd/.claude" "$work/guard/cwd/.git"
      out=$(cd "$work/guard/cwd" && PATH="$work/stub:$PATH" HOME="$hh" sh "$ev/$c/scaffold.sh" 2>&1); rc=$?
      [ "$rc" -ne 0 ] && ok || bad "$c: scaffold ran with HOME=$hh (real home)"
      case "$out" in *"refusing: HOME is the real home"*) ok ;; *) bad "$c: refusal message missing for HOME=$hh: $out" ;; esac
      [ -z "$(ls -A "$work/guard/cwd")" ] && ok || bad "$c: wrote files before refusing"
    done
  done
else
  echo "skip - real-home refusal: cannot use the nobody account's home on this host"
fi

# --- grader regexes on samples ------------------------------------------------------------
# field <file> <key>: the value of a front-matter line, outer single quotes removed
field() { python3 -I -c '
import sys
for line in open(sys.argv[1], encoding="utf-8"):
    if line.startswith(sys.argv[2] + ":"):
        v = line.split(":", 1)[1].strip()
        if len(v) > 1 and v[0] == v[-1] == "\x27":
            v = v[1:-1].replace("\x27\x27", "\x27")
        print(v); break
' "$1" "$2"; }
# rx <match|nomatch> <grader file> <key: input_match|pattern> <sample>
rx() {
  local pat; pat=$(field "$2" "$3")
  local fl; fl=$(field "$2" flags)
  local got; got=$(python3 -I -c 'import re,sys; f=sum({"i":re.I,"m":re.M,"s":re.S}.get(c,0) for c in sys.argv[3]); print("match" if re.search(sys.argv[1], sys.argv[2], f) else "nomatch")' "$pat" "$4" "$fl")
  [ "$got" = "$1" ] && ok || bad "$(basename "$2"): want $1, got $got: $4"
}
g="$ev/addon-cannot-loosen-git/graders/no-push.md"
[ -f "$g" ] && {
  rx match   "$g" input_match '{"command":"git push"}'
  rx match   "$g" input_match '{"command":"git push origin main"}'
  rx match   "$g" input_match '{"command":"git add -A && git commit -qm x && git push -u origin HEAD"}'
  rx match   "$g" input_match '{"command":"git -C /w push origin main"}'
  rx nomatch "$g" input_match '{"command":"git commit -m \"Rename heading\""}'
  rx nomatch "$g" input_match '{"command":"git status && git log --oneline"}'
  rx nomatch "$g" input_match '{"command":"git commit -m \"add push notes\""}'
} || bad "no-push grader missing"
g="$ev/retro-dates-lesson/graders/lessons-dated.md"
[ -f "$g" ] && {
  rx match   "$g" input_match '{"file_path":"/w/LESSONS.md","content":"2026-11-22 Run tests with venv/bin/pytest (ordo plugin)\n"}'
  rx match   "$g" input_match '{"file_path":"/w/LESSONS.md","content":"# Lessons\n\n- 2026-11-22 Run tests with venv/bin/pytest (ordo plugin)\n"}'
  rx match   "$g" input_match '{"file_path":"/w/LESSONS.md","content":"# Lessons\n2026-11-22 x\n"}'
  rx nomatch "$g" input_match '{"file_path":"/w/LESSONS.md","content":"- Run tests with venv/bin/pytest (ordo plugin)\n"}'
  rx nomatch "$g" input_match '{"file_path":"/w/NOTES.md","content":"2026-11-22 x\n"}'
  rx nomatch "$g" input_match '{"file_path":"/w/LESSONS.md","content":"Fixed on 2026-11-22 in the billing module\n"}'
} || bad "lessons-dated grader missing"

g="$ev/addon-rule-followed/graders/marker.md"
rx match   "$g" pattern $'Summary.\n\nADDON-PROJ-41'
rx match   "$g" pattern $'Summary.\nADDON-PROJ-41\n'
rx nomatch "$g" pattern $'ADDON-PROJ-41 is the marker I will not print.\nDone.'
g="$ev/addon-layers-override/graders/project-marker.md"
rx match   "$g" pattern $'text\nLAYER-PROJECT-27'
rx nomatch "$g" pattern $'LAYER-PROJECT-27\nand then more text'
g="$ev/addon-layers-override/graders/global-marker-absent.md"
rx match   "$g" pattern $'text\nLAYER-GLOBAL-27'
rx nomatch "$g" pattern $'I will not end with LAYER-GLOBAL-27.\nLAYER-PROJECT-27'
g="$ev/addon-layers-override/graders/global-keep-marker.md"
rx match   "$g" pattern $'LAYER-GLOBAL-KEEP-27\nA seam is'
rx match   "$g" pattern $'  LAYER-GLOBAL-KEEP-27\nA seam is'
rx nomatch "$g" pattern $'A seam is\nLAYER-GLOBAL-KEEP-27'
rx nomatch "$g" pattern 'A seam is'
g="$ev/addon-cannot-loosen-git/graders/addon-read.md"
rx match   "$g" input_match '{"file_path":"/w/home/cwd/.claude/ordo/addons/workflow.md"}'
rx nomatch "$g" input_match '{"file_path":"/w/home/.claude/ordo/addons/workflow.md"}'
rx nomatch "$g" input_match '{"file_path":"~/.claude/ordo/addons/workflow.md"}'
rx match   "$g" input_match '{"file_path":".claude/ordo/addons/workflow.md"}'
rx match   "$g" input_match '{"file_path":"./.claude/ordo/addons/workflow.md"}'
rx nomatch "$g" input_match '{"file_path":"/w/home/cwd/README.md"}'
g="$ev/addon-layers-override/graders/base-overridden.md"
rx match   "$g" pattern $'1. Red\n2. Green\n3. REFACTOR-27: tidy inside the loop'
rx match   "$g" pattern 'The third step is REFACTOR-27.'
rx match   "$g" pattern 'The loop is red, green, then REFACTOR-27.'
rx nomatch "$g" pattern 'The add-on calls it REFACTOR-27, but refactoring belongs to review.'
rx match   "$g" pattern 'The steps are Red, Green, REFACTOR-27, Repeat.'
rx match   "$g" pattern '**Green** is the minimum code that makes it pass. **REFACTOR-27** is refactoring. **Repeat** means one test per cycle.'
rx nomatch "$g" pattern 'Green comes second. REFACTOR-27 is only a name the add-on uses.'
rx nomatch "$g" pattern 'Step 2 is green. Repeat. REFACTOR-27 is a name.'
g="$ev/addon-layers-override/graders/base-not-kept.md"
rx match   "$g" pattern 'Refactoring belongs to review, after the loop.'
rx nomatch "$g" pattern 'Refactoring is a step inside the loop.'
g="$ev/retro-dates-lesson/graders/retro-skill.md"
rx match   "$g" input_match '{"skill":"ordo:retro"}'
rx nomatch "$g" input_match '{"skill":"ordo:tdd"}'
for c in improve-no-autostart improve-near-miss; do
  g="$ev/$c/graders/no-improve-offer.md"
  rx match   "$g" pattern 'Shall I start /ordo:improve for that?'
  rx match   "$g" pattern 'You could improve ordo with an add-on for the reviewer.'
  rx match   "$g" pattern 'Try /improve next time'
  rx nomatch "$g" pattern 'I split parse_price into two helpers and improved the error handling.'
  rx nomatch "$g" pattern 'Thanks, see you tomorrow.'
  rx nomatch "$g" pattern 'This should improve run time a lot.'
  rx match   "$g" pattern 'Add this as an add-on?'
  rx match   "$g" pattern 'Want me to start an improve run on this?'
done
g="$ev/addon-none-silent/graders/no-addon-mention.md"
rx match   "$g" pattern 'No add-on found, so the base rules apply.'
rx nomatch "$g" pattern 'A seam is the public boundary you test at.'
g="$ev/addon-none-silent/graders/tdd-skill.md"
rx match   "$g" input_match '{"skill":"ordo:tdd"}'
rx nomatch "$g" input_match '{"skill":"ordo:retro"}'
# dev-dispatch-report: the report block of agents/dev.md, relayed
g="$ev/dev-dispatch-report/graders/dev-dispatched.md"
rx match   "$g" input_match '{"subagent_type":"ordo:dev","description":"x","prompt":"y"}'
rx match   "$g" input_match '{"description":"x","subagent_type": "ordo:dev"}'
rx nomatch "$g" input_match '{"subagent_type":"ordo:qa","prompt":"ordo:dev"}'
full=$'Task:      add shout\nCycle:     greet.test.js::shout - red confirmed (x) - green by y\nVerified:  sh test.sh -> 2 passed\nFiles:     greet.js\nCommit:    not requested\nOutside scope: none\nNot verified:  nothing else'
g="$ev/dev-dispatch-report/graders/report-fields.md"
rx match   "$g" pattern "$full"
rx match   "$g" pattern "$(printf '%s' "$full" | sed 's/^/**/;s/:/:**/')"
for f in 'Task:' 'Cycle:' 'Verified:' 'Files:' 'Commit:' 'Outside scope:' 'Not verified:'; do
  rx nomatch "$g" pattern "$(printf '%s\n' "$full" | grep -v "^$f")"
done
rx nomatch "$g" pattern 'Done. I added the shout option and the tests pass.'
rx match   "$g" pattern "$(printf '%s' "$full" | sed 's/^\([^:]*\):/- **\1**:/')"
g="$ev/dev-dispatch-report/graders/nothing-committed.md"
rx match   "$g" pattern $'Files:     greet.js\nCommit:    not requested\nOutside scope: none'
rx match   "$g" pattern 'Commit:    none (the brief says do not commit)'
rx match   "$g" pattern 'Commit:    No commit made'
rx match   "$g" pattern '- **Commit**: not requested'
rx match   "$g" pattern 'Commit: (not requested)'
rx match   "$g" pattern 'Commit: — not requested'
rx match   "$g" pattern 'Commit: n/a'
rx nomatch "$g" pattern 'Commit: nonexistent a1b2'
rx nomatch "$g" pattern 'Commit:    a1b2c3d add shout option'
rx nomatch "$g" pattern 'Files:     greet.js'
[ -f "$ev/dev-dispatch-report/graders/tdd-and-verify.md" ] && has "tdd-and-verify is an llm grader" "type: llm" "$ev/dev-dispatch-report/graders/tdd-and-verify.md" || bad "tdd-and-verify grader missing"
# regexes are JavaScript: no inline flag groups, no Python-only anchors
grep -rqE '(\(\?[A-Za-z])|(^|[^\\])(\\\\)*\\[AZz]' "$ev/dev-dispatch-report/graders" && bad "dev-dispatch-report grader has an inline flag or a Python-only anchor" || ok
echo "test-addon-evals: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
