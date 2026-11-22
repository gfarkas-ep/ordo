#!/bin/bash
# Tests for plugins/ordo/skills/workflow/stall-check.sh. Free: fake helpers (sleep, cat, yes) and temp files only, no network, no model.
# Seam: script args + a process tree under --root -> stdout lines, stderr, exit code. Set STALL_CHECK=<path> to test a mutated copy; the copy must keep the file name stall-check.sh (the watcher exclusion matches on that name).
set -u

root=$(cd "$(dirname "$0")/.." && pwd)
S=${STALL_CHECK:-$root/plugins/ordo/skills/workflow/stall-check.sh}
tmp_root=${TMPDIR:-/tmp}
tmp_root=${tmp_root%/}
work=$(mktemp -d "$tmp_root/stall-test.XXXXXX")
cleanup() {
  if [ -n "${work:-}" ] && [ -d "$work" ] && [ "${work#"$tmp_root"/}" != "$work" ]; then
    rm -r "$work"
  fi
}
# grow FILE [touch]: background writer outside the --root tree (a writer inside would gain CPU time and hide the size rule)
app=
grow() { ( while :; do echo x >> "$1"; [ -z "${2:-}" ] || touch -t 200001010000 "$1"; sleep 0.3; done ) >/dev/null 2>&1 & app=$!; disown "$app" 2>/dev/null; }
stopgrow() { [ -z "$app" ] || { kill "$app" 2>/dev/null; wait "$app" 2>/dev/null; }; app=; }
trap "stopgrow; cleanup" EXIT

pass=0
fail=0
ok() { echo "ok   - $1"; pass=$((pass + 1)); }
bad() { echo "FAIL - $1"; fail=$((fail + 1)); }
# expect <name> <grep -E pattern> : stdout of the last run must match
want() { if printf '%s\n' "$out" | grep -Eq -- "$2"; then ok "$1"; else bad "$1 (stdout: [$out])"; fi; }
# wantf <name> <fixed string> : stdout of the last run must contain it
wantf() { if printf '%s\n' "$out" | grep -Fq -- "$2"; then ok "$1"; else bad "$1 (stdout: [$out])"; fi; }
# nowant <name> <grep -E pattern> : stdout of the last run must not match
nowant() { if printf '%s\n' "$out" | grep -Eq -- "$2"; then bad "$1 (stdout: [$out])"; else ok "$1"; fi; }

# Every case runs its fake helpers inside a command substitution: the subshell pid (read from a direct child sh; macOS bash 3.2 has no BASHPID) is the --root, children die with the trap.
# Background children get stdout to /dev/null so the substitution can end.
# killtree PID: kill its children first, then it (pkill -P alone orphans the sleep under an sh -c helper)
killtree() { local c; for c in $(pgrep -P "$1" 2>/dev/null); do killtree "$c"; done; kill "$1" 2>/dev/null; }
KILL='for c in $(pgrep -P "$me" 2>/dev/null); do killtree "$c"; done'

# case 1: sleep 31 | cat idle, flat transcript -> suspect line naming cat
t=$work/t1; echo hi > "$t"
out=$( trap "$KILL" EXIT; sh -c 'echo $PPID' >"$work/me"; me=$(cat "$work/me"); sleep 31 | cat >/dev/null & sleep 0.3
  sh "$S" --transcript "$t" --check 1 --max-checks 3 --root "$me" 2>"$work/err" )
want "1: idle cat on a pipe, flat transcript: suspect line" '^suspect: no growth, no child CPU; transcript=3; idle: '
want "1: suspect line names cat" '^suspect: .*idle: .*[0-9] cat( |$)'
want "1: suspect line names the pipe writer sleep" 'idle: .*[0-9] sleep 31'

# case 2a: growing transcript, idle child -> none (growth alone keeps it quiet)
t=$work/t2a; echo hi > "$t"
grow "$t"
out=$( trap "$KILL" EXIT; sh -c 'echo $PPID' >"$work/me"; me=$(cat "$work/me"); sleep 31 | cat >/dev/null &
  sh "$S" --transcript "$t" --check 1 --max-checks 3 --root "$me" 2>"$work/err" )
stopgrow
nowant "2a: growing transcript with an idle child: no suspect" '^suspect'
# case 2b: growing transcript + busy child -> none
t=$work/t2b; echo hi > "$t"
grow "$t"
out=$( trap "$KILL" EXIT; sh -c 'echo $PPID' >"$work/me"; me=$(cat "$work/me"); yes >/dev/null &
  sh "$S" --transcript "$t" --check 1 --max-checks 3 --root "$me" 2>"$work/err" )
stopgrow
nowant "2b: growing transcript with a busy child: no suspect" '^suspect'

# case 3: growing transcript through a symlink -> none
t=$work/t3; echo hi > "$t.real"; ln -s "$t.real" "$t"
grow "$t.real"
out=$( trap "$KILL" EXIT; sh -c 'echo $PPID' >"$work/me"; me=$(cat "$work/me"); sleep 31 | cat >/dev/null &
  sh "$S" --transcript "$t" --check 1 --max-checks 3 --root "$me" 2>"$work/err" )
stopgrow
nowant "3: growing symlinked transcript: no suspect" '^suspect'

# case 4: size grows, mtime frozen -> none
t=$work/t4; echo hi > "$t"
grow "$t" touch
out=$( trap "$KILL" EXIT; sh -c 'echo $PPID' >"$work/me"; me=$(cat "$work/me"); sleep 31 | cat >/dev/null &
  sh "$S" --transcript "$t" --check 1 --max-checks 3 --root "$me" 2>"$work/err" )
stopgrow
nowant "4: growing size with frozen mtime: no suspect" '^suspect'

# case 5: --pattern
t=$work/t5; echo hi > "$t"
out=$( trap "$KILL" EXIT; sh -c 'echo $PPID' >"$work/me"; me=$(cat "$work/me"); sleep 31 | cat >/dev/null & sleep 0.3
  sh "$S" --transcript "$t" --check 1 --max-checks 3 --root "$me" --pattern 'sleep 3' 2>"$work/err" )
nowant "5: --pattern 'sleep 3' finds the running sleep 31" 'no process matches'
out=$( trap "$KILL" EXIT; sh -c 'echo $PPID' >"$work/me"; me=$(cat "$work/me"); sh "$S" --transcript "$t" --check 1 --max-checks 3 --root "$me" --pattern 'zzq-no-such-proc-77' 2>"$work/err" )
want "5: no such process: reported, not satisfied by the script's own command line" "no process matches 'zzq-no-such-proc-77'"

# case 7+8b: flat 3 checks with a busy child (yes) and an idle one (cat): flat line, lists cat, not yes
t=$work/t7; echo hi > "$t"
out=$( trap "$KILL" EXIT; sh -c 'echo $PPID' >"$work/me"; me=$(cat "$work/me"); yes >/dev/null & sleep 31 | cat >/dev/null & sleep 0.3
  sh "$S" --transcript "$t" --check 1 --max-checks 4 --root "$me" 2>"$work/err" )
want "7: flat 3 checks, busy child present: flat line" '^suspect: transcript flat 3 checks; transcript=3; idle: '
want "8: idle cat listed" 'idle: .*[0-9] cat( |$)'
nowant "8: busy yes not listed as idle" '[0-9] yes( |$|\|)'
nowant "7: busy child: no 'no child CPU' line" 'no growth, no child CPU'
# case 8a: flat 2 checks + busy child: nothing
out=$( trap "$KILL" EXIT; sh -c 'echo $PPID' >"$work/me"; me=$(cat "$work/me"); yes >/dev/null & sleep 31 | cat >/dev/null & sleep 0.3
  sh "$S" --transcript "$t" --check 1 --max-checks 3 --root "$me" 2>"$work/err" )
[ -z "$out" ] && ok "8: flat transcript, busy child, under 3 checks: no output" || bad "8: expected no output (stdout: [$out])"

# first check is the baseline: one check only, no output
out=$( trap "$KILL" EXIT; sh -c 'echo $PPID' >"$work/me"; me=$(cat "$work/me"); sleep 31 | cat >/dev/null & sleep 0.3
  sh "$S" --transcript "$t" --check 1 --max-checks 1 --root "$me" 2>"$work/err" )
[ -z "$out" ] && ok "baseline check prints nothing" || bad "baseline printed (stdout: [$out])"

# missing transcript and broken symlink: no crash, size 0, at most one stderr line, CPU check still runs
for kind in missing broken; do
  t=$work/t-$kind
  [ $kind = broken ] && ln -s "$work/no-such-target" "$t"
  out=$( trap "$KILL" EXIT; sh -c 'echo $PPID' >"$work/me"; me=$(cat "$work/me"); sleep 31 | cat >/dev/null & sleep 0.3
    sh "$S" --transcript "$t" --check 1 --max-checks 3 --root "$me" 2>"$work/err" ); rc=$?
  [ "$rc" = 0 ] && ok "$kind transcript: exit 0" || bad "$kind transcript: exit $rc"
  want "$kind transcript: size reads 0, CPU check still runs, idle cat named" '^suspect: no growth, no child CPU; transcript=0; idle: .*[0-9] cat( |$)'
  want "$kind transcript: note on stdout" "^note: cannot read transcript .*t-$kind, size counted as 0"
  [ "$(printf '%s\n' "$out" | grep -c '^note:')" = 1 ] && ok "$kind transcript: the note comes once" || bad "$kind transcript: note count (stdout: [$out])"
  [ "$(wc -l < "$work/err" | tr -d ' ')" -le 1 ] && ok "$kind transcript: at most one stderr line" || bad "$kind transcript: stderr: $(cat "$work/err")"
done

# --file growth counts as growth (flat transcript)
t=$work/t9; echo hi > "$t"; f=$work/f9; echo a > "$f"
grow "$f"
out=$( trap "$KILL" EXIT; sh -c 'echo $PPID' >"$work/me"; me=$(cat "$work/me"); sleep 31 | cat >/dev/null &
  sh "$S" --transcript "$t" --check 1 --max-checks 3 --root "$me" --file "$f" 2>"$work/err" )
stopgrow
nowant "--file growing, transcript flat: no suspect" '^suspect'

# pattern is literal text: regex metacharacters neither break the check nor match as a regex
t=$work/t10; echo hi > "$t"
out=$( trap "$KILL" EXIT; sh -c 'echo $PPID' >"$work/me"; me=$(cat "$work/me"); sh -c 'sleep 31; true' 'x(20' >/dev/null 2>&1 & sleep 0.3
  sh "$S" --transcript "$t" --check 1 --max-checks 3 --root "$me" --pattern 'x(20' 2>"$work/err" )
nowant "pattern 'x(20' found literally" 'no process matches'
[ ! -s "$work/err" ] && ok "pattern with ( : nothing on stderr" || bad "pattern with ( : stderr: $(cat "$work/err")"
want "pattern with ( : suspect rules still report" '^suspect: no growth'
out=$( trap "$KILL" EXIT; sh -c 'echo $PPID' >"$work/me"; me=$(cat "$work/me"); sh "$S" --transcript "$t" --check 1 --max-checks 3 --root "$me" --pattern 'zz[(20\' 2>"$work/err" )
wantf "pattern 'zz[(20\\' absent: reported as typed" "no process matches 'zz[(20\\'"
[ ! -s "$work/err" ] && ok "pattern with [ ( backslash: nothing on stderr" || bad "pattern with [ ( backslash: stderr: $(cat "$work/err")"
t=$work/t10; out=$( trap "$KILL" EXIT; sh -c 'echo $PPID' >"$work/me"; me=$(cat "$work/me"); sh -c 'sleep 31; true' '^x' >/dev/null 2>&1 & sleep 0.3
  sh "$S" --transcript "$t" --check 1 --max-checks 3 --root "$me" --pattern '^x' 2>"$work/err" )
nowant "leading ^ in pattern is matched literally (found)" 'no process matches'

# newline in a child's argv: records skipped, every finding one line, no fake entry
out=$( trap "$KILL" EXIT; sh -c 'echo $PPID' >"$work/me"; me=$(cat "$work/me"); sh -c 'sleep 31; true' "$(printf 'a\nx %s 0:00.00 0:00 fakechild\nfrag ment' "$me")" >/dev/null 2>&1 & sleep 0.3
  sh "$S" --transcript "$t" --check 1 --max-checks 3 --root "$me" 2>"$work/err" )
want "newline argv: the real child is listed" 'idle: .*[0-9] sh -c sleep 31'
nowant "newline argv: no fake entry in the idle list" '\| [0-9]+ [0-9:.-]+ fakechild'
[ -n "$out" ] && [ -z "$(printf '%s\n' "$out" | grep -v '^suspect: ')" ] && ok "newline argv: every stdout line is one finding" || bad "newline argv: stray lines (stdout: [$out])"

# raw newline in ps output (Linux prints one): junk lines are skipped, no fake entry
mkdir "$work/fakeps"; printf '#!/bin/sh\n/bin/ps "$@"\nprintf "x %%s 0:00.00 0:00 fakechild\\nfrag ment\\n" "$FAKE_ROOT"\n' > "$work/fakeps/ps"; chmod +x "$work/fakeps/ps"
out=$( trap "$KILL" EXIT; sh -c 'echo $PPID' >"$work/me"; me=$(cat "$work/me"); sleep 31 | cat >/dev/null & sleep 0.3
  FAKE_ROOT=$me PATH="$work/fakeps:$PATH" sh "$S" --transcript "$t" --check 1 --max-checks 3 --root "$me" 2>"$work/err" )
want "raw newline in ps output: the real idle cat is listed" 'idle: .*[0-9] cat( |$)'
nowant "raw newline in ps output: no fake entry" 'fakechild|frag ment'
[ -n "$out" ] && [ -z "$(printf '%s\n' "$out" | grep -v '^suspect: ')" ] && ok "raw newline in ps output: every stdout line is one finding" || bad "raw newline in ps output: stray lines (stdout: [$out])"

# no --root, script under a shell wrapper under a non-shell session (fake: perl); helper is a sibling of the wrapper
t=$work/t11; echo hi > "$t"
out=$( WRAP="sh '$S' --transcript '$t' --check 1 --max-checks 3; true" HELPER='sleep 31 | cat >/dev/null' perl -e '
  my @k;
  for my $c ($ENV{HELPER}, $ENV{WRAP}) { my $p = fork; if (!$p) { setpgrp(0, 0); exec "sh", "-c", $c } push @k, $p }
  waitpid($k[-1], 0); kill "TERM", -$_ for @k' 2>"$work/err" )
want "auto root: walks past the shell wrapper, sees the sibling helper's idle cat" '^suspect: no growth, no child CPU; transcript=3; idle: .*[0-9] cat( |$)'
nowant "auto root: the wrapper shell and the script are not listed" 'stall-check|sh -c sh '

# two instances under one root: neither lists the other
t=$work/t12; echo hi > "$t"
out=$( trap "$KILL" EXIT; sh -c 'echo $PPID' >"$work/me"; me=$(cat "$work/me"); sleep 31 | cat >/dev/null & sleep 0.3
  sh "$S" --transcript "$t" --check 1 --max-checks 3 --root "$me" >"$work/a.out" 2>&1 & a=$!
  sh "$S" --transcript "$t" --check 1 --max-checks 3 --root "$me" 2>"$work/err"; wait $a )
want "two instances: second one still reports the idle cat" '^suspect: .*idle: .*[0-9] cat( |$)'
nowant "two instances: second one does not list the first" 'stall-check|awk|ps -A'
if grep -Eq 'stall-check|awk|ps -A' "$work/a.out"; then bad "two instances: first one lists the second ($(cat "$work/a.out"))"; else ok "two instances: first one does not list the second"; fi

# argument validation: exit 2, no endless loop (runrc gives 99 when the script was still running after 4 s)
runrc() { sh "$S" "$@" >"$work/o" 2>&1 & local p=$! i=0; while kill -0 $p 2>/dev/null && [ $i -lt 8 ]; do sleep 0.5; i=$((i + 1)); done
  if kill -0 $p 2>/dev/null; then kill $p; wait $p 2>/dev/null; return 99; fi; wait $p; }
runrc --transcript "$t" --check 1 --max-checks abc; [ $? = 2 ] && ok "--max-checks abc: exit 2" || bad "--max-checks abc: not exit 2"
runrc --transcript "$t" --check 1 --max-checks 0; [ $? = 2 ] && ok "--max-checks 0: exit 2" || bad "--max-checks 0: not exit 2"
runrc --transcript "$t" --check 1 --max-checks 2 --root abc; [ $? = 2 ] && ok "--root abc: exit 2" || bad "--root abc: not exit 2"

# ps that prints nothing: one stdout line, never silence
mkdir "$work/fakebin"; printf '#!/bin/sh\nexit 0\n' > "$work/fakebin/ps"; chmod +x "$work/fakebin/ps"
out=$(PATH="$work/fakebin:$PATH" sh "$S" --transcript "$t" --check 1 --max-checks 2 --root 1 2>"$work/err")
want "empty ps: check failed line" '^suspect: check failed: ps returned nothing'
out=$(sh "$S" --transcript "$t" --check 1 --max-checks 1 --root 999999 2>"$work/err")
want "root process not found: check failed line" '^suspect: check failed: root process 999999 not found'

# T1b: --report, --next-report, --pid, signals, entry shortening, narrow watcher exclusion
nreports() { printf '%s\n' "$out" | grep -c '^report:'; }
t=$work/t20; echo hi > "$t"; f=$work/f20; echo a > "$f"
out=$( trap "$KILL" EXIT; sh -c 'echo $PPID' >"$work/me"; me=$(cat "$work/me"); sleep 31 | cat >/dev/null & sleep 0.3
  sh "$S" --transcript "$t" --check 1 --report 2 --max-checks 4 --root "$me" --file "$f" --pattern 'sleep 3' 2>"$work/err" )
want "report: line with its fields at the report interval" '^report: transcript=3 \(\+0 since last report\); child CPU \+0\.00s; files: .*/f20=2; pattern: found; idle: .*[0-9] cat( |$)'
[ "$(nreports)" = 1 ] && ok "report: one report in 4 checks at report 2, check 1" || bad "report: expected 1 report (stdout: [$out])"
out=$( trap "$KILL" EXIT; sh -c 'echo $PPID' >"$work/me"; me=$(cat "$work/me"); sleep 31 | cat >/dev/null & sleep 0.3
  sh "$S" --transcript "$t" --check 1 --report 2 --max-checks 4 --root "$me" 2>"$work/err" )
want "report: no --file and no --pattern: files none, no pattern field" '^report: .*; files: none; idle: '
nowant "report: no pattern field without --pattern" 'pattern:'
t=$work/t21; echo hi > "$t"; grow "$t"
out=$( trap "$KILL" EXIT; sh -c 'echo $PPID' >"$work/me"; me=$(cat "$work/me"); yes >/dev/null & sleep 0.3
  sh "$S" --transcript "$t" --check 1 --report 2 --max-checks 3 --root "$me" 2>"$work/err" ); stopgrow
want "report: growth delta and child CPU gained" '^report: transcript=[0-9]+ \(\+[1-9][0-9]* since last report\); child CPU \+[1-9]\.[0-9]{2}s'
t=$work/t20
out=$( trap "$KILL" EXIT; sh -c 'echo $PPID' >"$work/me"; me=$(cat "$work/me"); sleep 31 | cat >/dev/null & sleep 0.3
  sh "$S" --transcript "$t" --check 2 --report 1 --max-checks 3 --root "$me" 2>"$work/err" )
[ "$(nreports)" = 2 ] && ok "report: check 2 s > report 1 s: one report per check" || bad "report: expected 2 reports (stdout: [$out])"
out=$( trap "$KILL" EXIT; sh -c 'echo $PPID' >"$work/me"; me=$(cat "$work/me"); sleep 31 | cat >/dev/null & sleep 0.3
  sh "$S" --transcript "$t" --check 1 --report 5 --next-report 2 --max-checks 4 --root "$me" 2>"$work/err" )
[ "$(nreports)" = 1 ] && ok "--next-report 2 shifts the first report before --report 5" || bad "--next-report: expected 1 report (stdout: [$out])"
out=$( trap "$KILL" EXIT; sh -c 'echo $PPID' >"$work/me"; me=$(cat "$work/me"); sleep 31 | cat >/dev/null & sleep 0.3
  sh "$S" --transcript "$t" --check 1 --max-checks 4 --root "$me" 2>"$work/err" )
[ "$(nreports)" = 0 ] && ok "no --report: no report line" || bad "no --report: report printed (stdout: [$out])"

# --pid: ended process exits 0 with no output; live process keeps the checks going
sh -c 'exit 0' & p=$!; wait $p
runrc --transcript "$t" --check 1 --pid "$p" --root $$; rc=$?
[ "$rc" = 0 ] && [ ! -s "$work/o" ] && ok "--pid of an ended process: exit 0, no output" || bad "--pid ended: rc=$rc output [$(cat "$work/o")]"
out=$( trap "$KILL" EXIT; sh -c 'echo $PPID' >"$work/me"; me=$(cat "$work/me"); sleep 31 | cat >/dev/null & sleep 0.3
  sh "$S" --transcript "$t" --check 1 --max-checks 3 --root "$me" --pid "$me" 2>"$work/err" )
want "--pid of a live process: checks go on" '^suspect: no growth'

# TERM and HUP: no output, no leftover sleep between checks
for sig in TERM HUP; do
  sh "$S" --transcript "$t" --check 17 --root $$ >"$work/term" 2>&1 & tp=$!
  sleep 1.5; kill -$sig $tp
  i=0; while kill -0 $tp 2>/dev/null && [ $i -lt 8 ]; do sleep 0.25; i=$((i + 1)); done
  if kill -0 $tp 2>/dev/null; then kill -KILL $tp; fi
  wait $tp 2>/dev/null; rc=$?
  left=$(ps -A -o command= | grep -c '[s]leep 17$')
  [ "$left" = 0 ] || pkill -f '[s]leep 17$'
  [ "$rc" = 0 ] && [ ! -s "$work/term" ] && [ "$left" = 0 ] && ok "$sig: exit 0, no output, no leftover sleep" || bad "$sig: rc=$rc leftover sleeps=$left output [$(cat "$work/term")]"
done

# idle entries: wrapper shortened to eval '<inner>', long entry cut to 120
out=$( trap "$KILL" EXIT; sh -c 'echo $PPID' >"$work/me"; me=$(cat "$work/me"); sh -c "true && eval 'sleep 31 | cat' < /dev/null" >/dev/null 2>&1 & sleep 0.3
  sh "$S" --transcript "$t" --check 1 --max-checks 3 --root "$me" 2>"$work/err" )
want "wrapper command shows as eval '<inner>'" "[0-9] eval 'sleep 31 \\| cat'( \\||\$)"
nowant "wrapper prefix is dropped" 'true &&'
long=$(head -c 190 /dev/zero | tr '\0' a)
out=$( trap "$KILL" EXIT; sh -c 'echo $PPID' >"$work/me"; me=$(cat "$work/me"); sh -c 'sleep 31; true' "$long" >/dev/null 2>&1 & sleep 0.3
  sh "$S" --transcript "$t" --check 1 --max-checks 3 --root "$me" 2>"$work/err" )
want "200-char command cut to 117 plus ..." '[0-9] sh -c sleep 31; true a{96}\.\.\.( \||$)'
nowant "long command not shown beyond the cut" 'a{97}'

# watcher exclusion is narrow: a helper whose argv merely holds a stall-check.sh path is still a child
out=$( trap "$KILL" EXIT; sh -c 'echo $PPID' >"$work/me"; me=$(cat "$work/me"); sh -c 'while :; do :; done' x "$S" >/dev/null 2>&1 & sleep 0.3
  sh "$S" --transcript "$t" --check 1 --max-checks 3 --root "$me" 2>"$work/err" )
[ -z "$out" ] && ok "helper with stall-check.sh as a later word: its CPU counts, no suspect" || bad "narrow exclusion: unexpected output [$out]"

# watcher running inside the Monitor-style wrapper (second word is -c / source): not listed, via the eval '<inner>' text
t=$work/t30; echo hi > "$t"
out=$( trap "$KILL" EXIT; sh -c 'echo $PPID' >"$work/me"; me=$(cat "$work/me"); sleep 31 | cat >/dev/null & sleep 0.3
  sh -c "true && eval 'sh $S --transcript $t --check 1 --max-checks 3 --root $me' < /dev/null && true" >"$work/b.out" 2>&1 & b=$!
  sh "$S" --transcript "$t" --check 1 --max-checks 3 --root "$me" 2>"$work/err"; wait $b )
want "wrapped sibling watcher: the idle cat is still listed" '^suspect: .*idle: .*[0-9] cat( |$)'
nowant "wrapped sibling watcher: its wrapper is not listed" 'eval|stall-check'
# sibling watcher started as `: > file; sh stall-check.sh ...` inside a wrapper: its wrapper is an ancestor of the instance, not listed
out=$( trap "$KILL" EXIT; sh -c 'echo $PPID' >"$work/me"; me=$(cat "$work/me"); sleep 31 | cat >/dev/null & sleep 0.3
  sh -c ": > $work/f31; sh $S --transcript $t --check 1 --max-checks 3 --root $me; true" >"$work/b.out" 2>&1 & b=$!
  sh "$S" --transcript "$t" --check 1 --max-checks 3 --root "$me" 2>"$work/err"; wait $b )
want "colon-prefixed sibling watcher: the idle cat is still listed" '^suspect: .*idle: .*[0-9] cat( |$)'
nowant "colon-prefixed sibling watcher: its wrapper is not listed" 'stall-check|sh -c :'

runrc --transcript "$t" --check 1 --max-checks 2 --next-report 2; rc=$?
[ "$rc" = 2 ] && [ "$(wc -l < "$work/o" | tr -d ' ')" = 1 ] && ok "--next-report without --report: exit 2, one stderr line" || bad "--next-report alone: rc=$rc output [$(cat "$work/o")]"

# argument validation (T1b)
runrc --transcript "$t" --check 1 --max-checks 2 --report abc; [ $? = 2 ] && ok "--report abc: exit 2" || bad "--report abc: not exit 2"
runrc --transcript "$t" --check 1 --max-checks 2 --report 0; [ $? = 2 ] && ok "--report 0: exit 2" || bad "--report 0: not exit 2"
runrc --transcript "$t" --check 1 --max-checks 2 --report 2 --next-report abc; [ $? = 2 ] && ok "--next-report abc: exit 2" || bad "--next-report abc: not exit 2"
runrc --transcript "$t" --check 1 --max-checks 2 --pid abc; [ $? = 2 ] && ok "--pid abc: exit 2" || bad "--pid abc: not exit 2"

# source greps: portable, no writes, no network, no model names
src=$(cat "$S" 2>/dev/null)
for w in stat timeout curl wget nohup; do
  if printf '%s\n' "$src" | grep -qw -- "$w"; then bad "script contains '$w'"; else ok "script has no '$w'"; fi
done
if printf '%s\n' "$src" | grep -vE '^[[:space:]]*#' | grep -E '>>?[[:space:]]*[^&[:space:]]' | grep -vE '>[[:space:]]*/dev/null' | grep -q .; then bad "script has a write redirection to a file"; else ok "script has no write redirection to a file"; fi
if printf '%s\n' "$src" | grep -qiE 'opus|sonnet|fable'; then bad "script names a model"; else ok "script names no model"; fi
[ -x "$S" ] && ok "script is executable" || bad "script is not executable"
[ -n "$src" ] && [ "$(head -1 "$S")" = '#!/bin/sh' ] && ok "script is POSIX sh (#!/bin/sh)" || bad "script lacks #!/bin/sh"

# no helper started by this run is left (sleep 31 is unique to this file)
sleep 0.5
left=$(ps -A -o command= | grep -Ec '[s]leep 31( |$)')
[ "$left" = 0 ] && ok "no sleep 31 helper left behind" || bad "$left sleep 31 helper(s) left behind"

echo
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ] || exit 1
