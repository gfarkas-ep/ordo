#!/bin/bash
# Tests for plugins/ordo/skills/feedback/usage-report.py (summary, redact, clear). Free: temp HOME, dummy log and dummy
# private terms, no network, no Claude run, never the real ~/.config/ordo or ~/.claude.
# Seam: helper argv + stdin + a temp HOME -> stdout, stderr, exit code and the files under that HOME.
# Set FEEDBACK_HELPER=<path> to test another script.
set -u

root=$(cd "$(dirname "$0")/.." && pwd)
helper=${FEEDBACK_HELPER:-$root/plugins/ordo/skills/feedback/usage-report.py}
tmp_root=${TMPDIR:-/tmp}
tmp_root=${tmp_root%/}
work=$(mktemp -d "$tmp_root/feedback-test.XXXXXX")
cleanup() {
  if [ -n "${work:-}" ] && [ -d "$work" ] && [ "${work#"$tmp_root"/}" != "$work" ]; then
    chmod -R u+rwx "$work" 2>/dev/null || true
    rm -r "$work"
  fi
}
trap cleanup EXIT

command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 2; }

export HOME="$work/home"
mkdir -p "$HOME/.claude" "$HOME/.config/ordo"
LOGDIR="$HOME/.config/ordo"
LOG="$LOGDIR/usage.jsonl"
TERMS="$LOGDIR/private-terms.txt"
MARK='[removed]'

fails=0
pass() { echo "ok   - $1"; }
fail() { echo "FAIL - $1"; fails=$((fails + 1)); }

# run <stdin-text> <args...>: sets out, err, rc (stdin text is passed as is, no trailing newline added)
run() {
  local input=$1; shift
  out=$(printf '%s' "$input" | python3 -I "$helper" "$@" 2>"$work/err"; echo "rc=$?")
  rc=${out##*rc=}; out=${out%rc=*}; out=${out%$'\n'}
  err=$(cat "$work/err")
}
has_line() { printf '%s\n' "$out" | grep -qxF -- "$1"; }
ts() { python3 -c 'import sys,time;print(time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime(time.time()-float(sys.argv[1])*86400)))' "$1"; }
# add <days-ago> <json fields without braces>: appends one log line
add() { printf '{"time":"%s",%s}\n' "$(ts "$1")" "$2" >> "$LOG"; }
NOW0=$(date +%s)
# adds <days-ago> <minutes-offset> <json fields without braces>: a line at a fixed moment (NOW0 - days + minutes)
adds() { printf '{"time":"%s",%s}\n' "$(python3 -c 'import sys,time;print(time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime(int(sys.argv[1])-float(sys.argv[2])*86400+float(sys.argv[3])*60)))' "$NOW0" "$1" "$2")" "$3" >> "$LOG"; }
snapshot() { # content hashes and the listing of HOME and of the skill dir
  local d
  for d in "$HOME" "$root/plugins/ordo/skills/feedback"; do
    (cd "$d" && find . -type f -print0 | sort -z | xargs -0 shasum -a 256; find . | sort) 2>/dev/null
  done
}

# ---------------------------------------------------------------- summary
# line shapes of the summary (the counts in every test below are literals, not computed)
# sk <name> runs failed aborted asked ran notallowed cancelled [denied]; ag adds never-finished, then [denied]
sk() { printf '  %s: runs %s, failed %s, aborted %s, asked %s, ran %s, not allowed %s, denied (auto mode) %s, cancelled (by you, or the session ended) %s' "$1" "$2" "$3" "$4" "$5" "$6" "$7" "${9:-0}" "$8"; }
ag() { printf '  %s: runs %s, failed %s, aborted %s, asked %s, ran %s, not allowed %s, denied (auto mode) %s, cancelled (by you, or the session ended) %s, started, never finished %s' "$1" "$2" "$3" "$4" "$5" "$6" "$7" "${10:-0}" "$8" "$9"; }
rm -f "$LOG"
for n in 1 2 3; do add "$n" '"kind":"skill","name":"tdd","result":"ok","version":"0.13.0","off":[],"session":"sesscode0001"'; done
add 1 '"kind":"skill","name":"tdd","result":"failed","version":"0.13.0","off":[],"session":"sesscode0001"'
add 2 '"kind":"skill","name":"tdd","result":"aborted","version":"0.13.0","off":[],"session":"sesscode0001"'
add 1 '"kind":"skill","name":"tdd","version":"0.13.0","off":[],"session":"sesscode0001"'  # no result: counts in nothing
add 1 '"kind":"skill","name":"goal","result":"ok","version":"0.13.0","off":[]'
add 4 '"kind":"skill","name":"feedback","result":"ok","version":"0.13.0","off":["qa_check"],"session":"sesscode0002"'
add 1 '"kind":"script","name":"stall-check","result":"ok","version":"0.13.0","off":[],"session":"sesscode0001"'
add 1 '"kind":"script","name":"stall-check","result":"ok","version":"0.13.0","off":[]'
add 1 '"kind":"script","name":"stall-check","result":"failed","version":"0.13.0","off":[]'
add 1 '"kind":"script","name":"usage-report","result":"ok","version":"0.13.0","off":[]'
add 1 '"kind":"script","name":"CANARY_SCRIPT","result":"ok"'
add 1 '"kind":"agent","name":"dev","result":"ok","version":"0.13.0","off":[],"agent":"agentcode001","session":"sesscode0001"'
add 2 '"kind":"agent","name":"dev","result":"ok","version":"0.13.0","off":[],"agent":"agentcode002"'
add 1 '"kind":"agent","name":"qa","result":"ok","version":"0.13.0","off":[],"agent":"agentcode003","verdict":"PASS"'
add 3 '"kind":"agent","name":"code-reviewer","result":"ok","version":"0.13.0","off":[],"agent":"agentcode004","verdict":"CHANGES"'
add 2 '"kind":"agent","name":"po","result":"ok","version":"0.13.0","off":[],"agent":"agentcode005","verdict":"ACCEPTED"'
add 2 '"kind":"agent","name":"qa","result":"ok","version":"0.13.0","off":[],"agent":"agentcode006","verdict":"APPROVED"'  # qa run with a word not allowed for it: a run, no verdict
add 1 '"kind":"agent","name":"qa","result":"ok","version":"0.13.0","off":[],"verdict":"CANARY_VERDICT"'
add 1 '"kind":"guard","family":"rebase","session":"sesscode0001"'
add 2 '"kind":"guard","family":"rebase"'
add 3 '"kind":"guard","family":"force-push"'
add 1 '"kind":"start","session":"sesscode0001"'
add 1 '"kind":"end","session":"sesscode0001"'
# outside the default period or not countable
add 45 '"kind":"skill","name":"goal","result":"ok","version":"0.13.0","off":[]'
for n in 1 2 3 4 5; do add 100 '"kind":"skill","name":"tdd","result":"ok","version":"0.13.0","off":[]'; done
add -5 '"kind":"skill","name":"tdd","result":"ok","version":"0.13.0","off":[]'
# junk and tampered values: never printed, never counted
add 1 '"kind":"skill","name":"CANARY_SKILL","result":"ok","version":"0.13.0","off":[]'
add 1 '"kind":"skill","name":"ordo:tdd","result":"ok","off":[]'
add 1 '"kind":"agent","name":"CANARY_AGENT","result":"ok","verdict":"PASS"'
add 1 '"kind":"skill","name":"tdd","result":"CANARY_RESULT"'
add 1 '"kind":"guard","family":"CANARY_FAMILY"'
add 1 '"kind":"CANARY_KIND","name":"tdd","result":"ok"'
printf 'not json at all CANARY_RAW\n[1,2,3]\n"CANARY_STRING"\n{"time":"CANARY_TIME","kind":"skill","name":"tdd","result":"ok"}\n\xff\xfe\x00 CANARY_BIN\n{"kind":"skill","name":"tdd","result":"ok"}\n{"time":"2026-1' >> "$LOG"

run '' summary
if [ "$rc" = 0 ]; then pass "summary default exits 0"; else fail "summary default exits 0 (rc=$rc err=$err)"; fi
case "$out" in *"last 30 days"*) pass "summary names the default period of 30 days";; *) fail "summary names the period: $out";; esac
has_line "$(sk tdd 5 1 1 0 0 0 0)" && has_line "$(sk feedback 1 0 0 0 0 0 0)" && has_line "$(sk goal 1 0 0 0 0 0 0)" && has_line "Skills:" && pass "summary counts runs, failed and aborted per skill (a line without result counts in nothing)" || fail "summary skill counts: $out"
has_line "$(ag qa 3 0 0 0 0 0 0 0)" && has_line "$(ag dev 2 0 0 0 0 0 0 0)" && has_line "$(ag code-reviewer 1 0 0 0 0 0 0 0)" && has_line "$(ag po 1 0 0 0 0 0 0 0)" && has_line "Agents:" && pass "summary counts runs per agent (finish lines)" || fail "summary agent counts: $out"
has_line "$(sk stall-check 3 1 0 0 0 0 0)" && has_line "$(sk usage-report 1 0 0 0 0 0 0)" && has_line "Scripts:" && pass "summary counts runs and failed per own script (a name not on the own list is dropped)" || fail "summary script counts: $out"
has_line "Verdicts: ACCEPTED 1, CHANGES 1, PASS 1" && pass "summary counts per verdict word (a word not allowed for the agent is dropped)" || fail "summary verdicts: $out"
has_line "Guard blocks: rebase 2, force-push 1" && pass "summary counts per guard family" || fail "summary guard counts: $out"
has_line "Agent run time: no times recorded" && pass "summary: no start lines give no run times" || fail "summary run time: $out"
for bad in CANARY sesscode0001 sesscode0002 agentcode ordo:tdd APPROVED; do
  case "$out$err" in *"$bad"*) fail "summary printed junk or a code: $bad";; *) pass "summary never prints '$bad'";; esac
done

run '' summary --days 90
has_line "$(sk goal 2 0 0 0 0 0 0)" && has_line "$(sk tdd 5 1 1 0 0 0 0)" && pass "--days 90 counts the 45-day line and still ignores the 100-day lines" || fail "--days 90 skills: $out"
run '' summary --days 3
has_line "$(sk tdd 4 1 1 0 0 0 0)" && has_line "$(sk goal 1 0 0 0 0 0 0)" && pass "--days 3 counts only the last 3 days" || fail "--days 3 skills: $out"
for d in 91 0 -1 abc 1.5 ''; do
  run '' summary --days "$d"
  if [ "$rc" != 0 ] && [ -z "$out" ]; then pass "--days '$d' is refused (rc=$rc)"; else fail "--days '$d' accepted: rc=$rc out=$out"; fi
  case "$err" in *"$d"*) [ -z "$d" ] || { [ "$d" = 0 ] || [ "$d" = 91 ] || [ "$d" = -1 ]; } || fail "error message echoes the value '$d'";; esac
done
run '' summary --days
[ "$rc" != 0 ] && pass "--days without a value is refused" || fail "--days without a value accepted"

before=$(snapshot)
run '' summary
run '' summary --days 90
[ "$(snapshot)" = "$before" ] && pass "summary writes nothing (HOME tree and helper dir unchanged)" || fail "summary changed the file tree"
[ -z "$(find "$root/plugins/ordo/skills/feedback" "$root/plugins/ordo/hooks" -name '__pycache__' -o -name '*.pyc' 2>/dev/null)" ] && pass "summary leaves no bytecode in the skill dir or the hooks dir" || fail "bytecode written by the summary"

# asked, ran, not allowed and cancelled (AC49, AC54): hand-built logs, one case each, literal expected counts.
# Line builders: <target> <name> <call code> for call, ask and denied; <kind> <name> <result> <call code> for a run line.
L_call() { add 1 "\"kind\":\"call\",\"target\":\"$1\",\"name\":\"$2\",\"session\":\"sesscode0001\",\"call\":\"$3\""; }
L_ask() { add 1 "\"kind\":\"ask\",\"target\":\"$1\",\"name\":\"$2\",\"session\":\"sesscode0001\",\"call\":\"$3\",\"version\":\"0.13.0\",\"off\":[]"; }
L_den() { add 1 "\"kind\":\"$1\",\"name\":\"$2\",\"result\":\"denied\",\"session\":\"sesscode0001\",\"call\":\"$3\",\"version\":\"0.13.0\",\"off\":[]"; }
L_run() { add 1 "\"kind\":\"$1\",\"name\":\"$2\",\"result\":\"$3\",\"session\":\"sesscode0001\",\"call\":\"$4\",\"version\":\"0.13.0\",\"off\":[]"; }
L_launch() { add 1 "\"kind\":\"launch\",\"session\":\"sesscode0001\",\"call\":\"$1\""; }
# case <name> <expected skill line>: the log is built by the lines before it, then cleared
case_sk() { run '' summary; if has_line "$2"; then pass "AC49/AC54: $1"; else fail "AC49/AC54: $1 (want '$2'): $out"; fi; rm -f "$LOG"; }
case_ag() { run '' summary; if has_line "$2"; then pass "AC49/AC54: $1"; else fail "AC49/AC54: $1 (want '$2'): $out"; fi; rm -f "$LOG"; }
C1=callcode0001; C2=callcode0002
rm -f "$LOG"
L_ask skill tdd $C1; L_ask skill tdd $C1; L_run skill tdd ok $C1
case_sk "asked twice, run once: one ran, one not allowed" "$(sk tdd 1 0 0 2 1 1 0)"
L_run skill tdd ok $C1
case_sk "run with no ask is a run, not asked" "$(sk tdd 1 0 0 0 0 0 0)"
L_ask skill tdd $C1
case_sk "ask with no run is not allowed" "$(sk tdd 0 0 0 1 0 1 0)"
L_call skill tdd $C1
case_sk "call with no outcome is cancelled" "$(sk tdd 0 0 0 0 0 0 1)"
L_call skill tdd $C1; L_den skill tdd $C1
case_sk "call then denied: denied once, not asked, not not-allowed, not cancelled" "$(sk tdd 0 0 0 0 0 0 0 1)"
L_den skill tdd $C1
case_sk "denied with no ask: denied, not asked, not not-allowed" "$(sk tdd 0 0 0 0 0 0 0 1)"
L_ask skill tdd $C1; L_den skill tdd $C1
case_sk "ask then denied (same code): denied once, the ask is not asked and not not-allowed" "$(sk tdd 0 0 0 0 0 0 0 1)"
L_den skill tdd $C1; L_ask skill tdd $C1
case_sk "denied before the ask does not settle it: asked, not allowed, and denied" "$(sk tdd 0 0 0 1 0 1 0 1)"
L_ask skill tdd $C1; L_ask skill tdd $C1; L_den skill tdd $C1
case_sk "two asks, one denied: one ask open and not allowed, one denied" "$(sk tdd 0 0 0 1 0 1 0 1)"
L_ask skill tdd $C1; L_den skill tdd $C2
case_sk "denied of another call code does not settle the ask: asked, not allowed, and denied" "$(sk tdd 0 0 0 1 0 1 0 1)"
L_ask skill tdd $C1; L_ask skill tdd $C1; L_den skill tdd $C1; L_run skill tdd ok $C1
case_sk "two asks, one denied, one run: the denial settles one ask only, the other ran" "$(sk tdd 1 0 0 1 1 0 0 1)"
L_call skill tdd $C1; L_ask skill tdd $C1; L_den skill tdd $C1
case_sk "call, ask, denied: denied only, never cancelled" "$(sk tdd 0 0 0 0 0 0 0 1)"
L_ask skill tdd $C1; L_den skill tdd $C1; L_run skill tdd ok $C1
case_sk "ask, denied, run: the denial settles the ask, the later run is not asked" "$(sk tdd 1 0 0 0 0 0 0 1)"
L_ask skill tdd $C1; L_run skill tdd ok $C1; L_run skill tdd ok $C1
case_sk "one ask, two runs of one call code: one ran, the second run is not asked" "$(sk tdd 2 0 0 1 1 0 0)"
L_ask skill tdd $C1; L_ask skill tdd $C1; L_run skill tdd ok $C1; L_run skill tdd ok $C1
case_sk "two asks, two runs: both ran, none not allowed" "$(sk tdd 2 0 0 2 2 0 0)"
L_call skill tdd $C1; L_ask skill tdd $C1; L_run skill tdd ok $C1
case_sk "call, ask, run: one run, asked and ran, not cancelled" "$(sk tdd 1 0 0 1 1 0 0)"
L_call skill tdd $C1; L_ask skill tdd $C1
case_sk "call, ask, nothing: not allowed only, never also cancelled" "$(sk tdd 0 0 0 1 0 1 0)"
L_call skill tdd $C1; L_call skill tdd $C1; L_run skill tdd ok $C1
case_sk "parallel identical calls, one run: one run, one cancelled" "$(sk tdd 1 0 0 0 0 0 1)"
L_call skill tdd $C1; L_call skill tdd $C1; L_ask skill tdd $C1; L_run skill tdd ok $C1
case_sk "call, call, ask, run: the run settles the ask first, the other call is cancelled" "$(sk tdd 1 0 0 1 1 0 1)"
L_call skill tdd $C1; L_call skill tdd $C2; L_run skill tdd ok $C2
case_sk "different call codes do not pair: one run, one cancelled" "$(sk tdd 1 0 0 0 0 0 1)"
L_call skill tdd $C1; L_run skill tdd ok $C2; L_call skill tdd $C1; L_run skill tdd ok $C1
case_sk "an unanswered call, then an identical call that runs: first cancelled, later a run" "$(sk tdd 2 0 0 0 0 0 1)"
L_call skill tdd $C1; L_run skill tdd ok $C2; L_call skill tdd $C1; L_call skill tdd $C1; L_run skill tdd ok $C1
case_sk "three calls of one code, one later run: two cancelled" "$(sk tdd 2 0 0 0 0 0 2)"
L_run skill tdd ok $C1; L_run skill tdd ok $C1
case_sk "run with no call line: runs, cancelled never below zero" "$(sk tdd 2 0 0 0 0 0 0)"
L_call skill tdd $C1; L_run skill tdd aborted $C1
case_sk "aborted is never cancelled" "$(sk tdd 1 0 1 0 0 0 0)"
L_call skill tdd $C1; L_ask skill tdd $C1; L_run skill tdd failed $C1
case_sk "asked and ran, but the run failed: ran, failed, not cancelled" "$(sk tdd 1 1 0 1 1 0 0)"
L_run skill tdd ok $C1; L_ask skill tdd $C1
case_sk "ask after the run: the run is not asked, the ask is not allowed" "$(sk tdd 1 0 0 1 0 1 0)"
L_ask skill tdd $C1; L_run skill tdd ok $C2
case_sk "ask and run with other call codes: not paired" "$(sk tdd 1 0 0 1 0 1 0)"
add 1 '"kind":"skill","name":"tdd","session":"sesscode0001","call":"callcode0001"'; L_call skill tdd $C1
case_sk "a skill line without result settles nothing: the call is cancelled, no run" "$(sk tdd 0 0 0 0 0 0 1)"
add 1 '"kind":"ask","target":"skill","name":"CANARY_SKILL","call":"callcode0001"'; add 1 '"kind":"call","target":"skill","name":"CANARY_SKILL","call":"callcode0001"'
add 1 '"kind":"ask","target":"CANARY_TARGET","name":"tdd","call":"callcode0001"'; add 1 '"kind":"ask","target":"agent","name":"tdd","call":"callcode0001"'; L_run skill tdd ok $C2
run '' summary
if [ "$rc" = 0 ] && has_line "$(sk tdd 1 0 0 0 0 0 0)" && ! printf '%s\n' "$out" | grep -qE 'CANARY|agent'; then pass "AC13: ask and call lines with a name or target not on the own lists are dropped"; else fail "dropped ask/call lines: $out"; fi
rm -f "$LOG"
L_call script stall-check $C1; L_ask script stall-check $C1; L_run script stall-check ok $C1; L_call script usage-report $C2; L_ask script usage-report $C2
run '' summary
if has_line "$(sk stall-check 1 0 0 1 1 0 0)" && has_line "$(sk usage-report 0 0 0 1 0 1 0)"; then pass "scripts: asked, ran, not allowed per script name"; else fail "script asks: $out"; fi
rm -f "$LOG"
# a Monitor launch of an own script (AC4): a run that pairs with its call and ask; the line adds how many were started through Monitor
L_runm() { add 1 "\"kind\":\"script\",\"name\":\"$1\",\"result\":\"$2\",\"via\":\"monitor\",\"session\":\"sesscode0001\",\"call\":\"$3\",\"version\":\"0.13.0\",\"off\":[]"; }
C3=callcode0003; C4=callcode0004; C5=callcode0005
MON=", started through Monitor %s (outcome not reported)"
L_call script stall-check $C1; L_ask script stall-check $C1; L_runm stall-check ok $C1
run '' summary
if has_line "$(sk stall-check 1 0 0 1 1 0 0)$(printf "$MON" 1)"; then pass "AC4 Monitor launch: a run that pairs with its call and ask, line adds the Monitor count"; else fail "monitor launch: $out"; fi
rm -f "$LOG"
L_call script stall-check $C1; L_runm stall-check ok $C1; L_call script stall-check $C2; L_run script stall-check ok $C2; L_call script stall-check $C3; L_runm stall-check failed $C3; L_den script stall-check $C4; add 1 '"kind":"script","name":"stall-check","result":"ok","via":"CANARY_VIA","call":"callcode0009"'; L_call script usage-report $C5; L_run script usage-report ok $C5
run '' summary
if has_line "$(sk stall-check 4 1 0 0 0 0 0 1)$(printf "$MON" 2)" && has_line "$(sk usage-report 1 0 0 0 0 0 0)" && ! printf '%s\n' "$out" | grep -q 'CANARY'; then pass "AC4 Monitor count is the via-monitor runs only (Bash runs, denied lines and other via values not counted); a name with none stays as before"; else fail "monitor mix: $out"; fi
rm -f "$LOG"
# asks of different names under one call code are counted under their own names
L_ask skill tdd $C1; L_ask skill goal $C1; L_run skill goal ok $C1
run '' summary
if has_line "$(sk tdd 0 0 0 1 1 0 0)" && has_line "$(sk goal 1 0 0 1 0 1 0)"; then pass "one-to-one in file order: the first ask of a call code is the one that ran"; else fail "ask order: $out"; fi
rm -f "$LOG"

# agents: asked and ran through the launch line or a failed or aborted Agent call line (AC49, AC51, AC54)
L_call agent dev $C1; L_ask agent dev $C1; L_launch $C1
case_ag "agent: call, ask, launch is asked and ran, not cancelled" "$(ag dev 0 0 0 1 1 0 0 0)"
L_call agent dev $C1; L_launch $C1
case_ag "background agent: the launch line is the call's outcome, never cancelled" "No usage recorded in the last 30 days."
L_call agent dev $C1; L_ask agent dev $C1
case_ag "agent ask with no launch: not allowed, not cancelled" "$(ag dev 0 0 0 1 0 1 0 0)"
L_call agent dev $C1
case_ag "agent call with no ask and no launch: cancelled" "$(ag dev 0 0 0 0 0 0 1 0)"
L_call agent dev $C1; L_run agent dev failed $C1
case_ag "failed Agent call (no agent code): one run, failed, not cancelled" "$(ag dev 1 1 0 0 0 0 0 0)"
L_call agent dev $C1; L_run agent dev aborted $C1
case_ag "aborted Agent call: one run, aborted, not cancelled" "$(ag dev 1 0 1 0 0 0 0 0)"
L_call agent dev $C1; L_ask agent dev $C1; L_run agent dev failed $C1
case_ag "asked agent call that then failed: asked and ran" "$(ag dev 1 1 0 1 1 0 0 0)"
L_launch $C1
case_ag "launch with no call line: nothing, never negative" "No usage recorded in the last 30 days."
L_call agent dev $C1; L_den agent dev $C1
case_ag "agent call then denied: denied once, not asked, not not-allowed, not cancelled" "$(ag dev 0 0 0 0 0 0 0 0 1)"
L_call agent dev $C1; L_ask agent dev $C1; L_den agent dev $C1
case_ag "agent ask then denied: denied once, the ask is not asked and not not-allowed" "$(ag dev 0 0 0 0 0 0 0 0 1)"

# agent start, finish and run time (AC8, AC51): codes pair a start with its finish; times are minutes after a fixed point
A_start() { adds 1 "$3" "\"kind\":\"agent-start\",\"name\":\"$1\",\"session\":\"sesscode0001\",\"agent\":\"$2\""; }
A_fin() { adds 1 "$3" "\"kind\":\"agent\",\"name\":\"$1\",\"result\":\"${4:-ok}\",\"session\":\"sesscode0001\",\"agent\":\"$2\",\"version\":\"0.13.0\",\"off\":[]"; }
A1=agentcode001; A2=agentcode002; A3=agentcode003
rm -f "$LOG"
L_call agent dev $C1; A_start dev $A1 0; A_fin dev $A1 1.5; L_launch $C1
run '' summary
if has_line "$(ag dev 1 0 0 0 0 0 0 0)" && has_line "Agent run time: dev total 90 s, average 90 s over 1 run"; then pass "AC8/AC51: foreground agent: call, start, finish, launch is one run of 90 s, never cancelled"; else fail "foreground agent: $out"; fi
rm -f "$LOG"
L_call agent dev $C1; A_start dev $A1 0; L_launch $C1; A_fin dev $A1 10
run '' summary
if has_line "$(ag dev 1 0 0 0 0 0 0 0)" && has_line "Agent run time: dev total 600 s, average 600 s over 1 run"; then pass "AC8/AC51: background agent: the run time is finish minus start, not the launch call"; else fail "background agent: $out"; fi
rm -f "$LOG"
A_start dev $A1 0; A_fin dev $A1 2; A_start dev $A2 5; A_fin dev $A2 6; A_start qa $A3 7; A_fin qa $A3 7.5
run '' summary
if has_line "$(ag dev 2 0 0 0 0 0 0 0)" && has_line "$(ag qa 1 0 0 0 0 0 0 0)" && has_line "Agent run time: dev total 180 s, average 90 s over 2 runs; qa total 30 s, average 30 s over 1 run"; then pass "AC8: run time total and average per agent name"; else fail "run time per name: $out"; fi
rm -f "$LOG"
A_start dev $A1 0
run '' summary
if has_line "$(ag dev 0 0 0 0 0 0 0 1)" && has_line "Agent run time: no times recorded"; then pass "AC8: a start with no finish is not a run, has no time, is reported as started, never finished"; else fail "start with no finish: $out"; fi
rm -f "$LOG"
A_fin dev $A1 1
run '' summary
if has_line "$(ag dev 1 0 0 0 0 0 0 0)" && has_line "Agent run time: no times recorded"; then pass "AC8: a finish with no start is a run with no time"; else fail "finish with no start: $out"; fi
rm -f "$LOG"
A_fin dev $A1 1; A_start dev $A1 2
run '' summary
if has_line "$(ag dev 1 0 0 0 0 0 0 1)" && has_line "Agent run time: no times recorded"; then pass "AC8: a start after the finish of the same code does not pair with it"; else fail "start after finish: $out"; fi
rm -f "$LOG"
A_start dev $A1 2; A_fin dev $A1 1
run '' summary
if has_line "$(ag dev 1 0 0 0 0 0 0 0)" && has_line "Agent run time: no times recorded"; then pass "AC8: a negative run time is dropped (the run still counts)"; else fail "negative run time: $out"; fi
rm -f "$LOG"
A_start dev $A1 0; A_start dev $A2 0.5; A_fin dev $A2 1; A_fin dev $A1 3
run '' summary
if has_line "Agent run time: dev total 210 s, average 105 s over 2 runs"; then pass "AC8: two agents of one name pair by their own codes (180 s and 30 s)"; else fail "two codes: $out"; fi
rm -f "$LOG"
# a failed or aborted Agent call whose agent also started and finished is one run, with the failed or aborted result (AC51).
# The call line is built as usage_log.py writes it: a call code and no agent code. The agent's own finish line has the verdict.
A_failcall() { adds 1 "$3" "\"kind\":\"agent\",\"name\":\"$1\",\"result\":\"$2\",\"session\":\"sesscode0001\",\"call\":\"$C1\",\"version\":\"0.13.0\",\"off\":[]"; }
A_finv() { adds 1 "$3" "\"kind\":\"agent\",\"name\":\"$1\",\"result\":\"ok\",\"session\":\"sesscode0001\",\"agent\":\"$2\",\"verdict\":\"$4\",\"version\":\"0.13.0\",\"off\":[]"; }
L_call agent qa $C1; A_start qa $A1 0; A_finv qa $A1 1 PASS; A_failcall qa failed 1.5
run '' summary
if has_line "$(ag qa 1 1 0 0 0 0 0 0)" && has_line "Verdicts: PASS 1" && has_line "Agent run time: qa total 60 s, average 60 s over 1 run"; then pass "AC51: failed Agent call (no agent code) plus its agent's start and finish: one run, failed, one verdict, one run time"; else fail "failed call, agent started: $out"; fi
rm -f "$LOG"
L_call agent qa $C1; A_start qa $A1 0; A_finv qa $A1 1 FAIL; A_failcall qa aborted 1.5
run '' summary
if has_line "$(ag qa 1 0 1 0 0 0 0 0)" && has_line "Verdicts: FAIL 1"; then pass "AC51: aborted Agent call plus its agent's start and finish: one run, aborted, one verdict"; else fail "aborted call, agent started: $out"; fi
rm -f "$LOG"
L_call agent qa $C1; A_failcall qa failed 1
run '' summary
if has_line "$(ag qa 1 1 0 0 0 0 0 0)"; then pass "AC51: a failed Agent call with no agent candidate is one failed run, not cancelled"; else fail "failed call alone: $out"; fi
rm -f "$LOG"
A_start qa $A1 0; A_start qa $A2 0.5; A_finv qa $A1 1 PASS; A_finv qa $A2 1.5 FAIL; A_failcall qa failed 2; A_failcall qa aborted 2.5
run '' summary
if has_line "$(ag qa 2 1 1 0 0 0 0 0)" && has_line "Verdicts: FAIL 1, PASS 1"; then pass "AC51: two agents of one name, two failed calls: first in, first out, two runs"; else fail "two agents, two failed calls: $out"; fi
rm -f "$LOG"
A_start qa $A1 0; A_start qa $A2 0.5; A_finv qa $A1 1 PASS; A_finv qa $A2 1.5 FAIL; A_failcall qa failed 2
run '' summary
if has_line "$(ag qa 2 1 0 0 0 0 0 0)"; then pass "AC51: two agents of one name, one failed call: two runs, one failed"; else fail "two agents, one failed call: $out"; fi
rm -f "$LOG"
A_start qa $A1 0; A_finv qa $A1 1 PASS; L_launch $C1; add 1 "\"kind\":\"launch\",\"session\":\"sesscode0001\",\"call\":\"callcode0009\",\"agent\":\"$A1\""; A_failcall qa failed 2
run '' summary
if has_line "$(ag qa 2 1 0 0 0 0 0 0)"; then pass "AC51: an agent with a launch line belongs to a successful call: the failed call is its own run"; else fail "launched agent: $out"; fi
rm -f "$LOG"
A_failcall qa failed 0; A_start qa $A1 1; A_finv qa $A1 2 PASS
run '' summary
if has_line "$(ag qa 2 1 0 0 0 0 0 0)"; then pass "AC51: an agent that started after the failed call is not its agent"; else fail "later agent: $out"; fi
rm -f "$LOG"
A_start qa $A1 0; A_finv qa $A1 1 PASS; adds 1 2 "\"kind\":\"agent\",\"name\":\"qa\",\"result\":\"failed\",\"session\":\"sesscode0002\",\"call\":\"$C1\""
run '' summary
if has_line "$(ag qa 2 1 0 0 0 0 0 0)"; then pass "AC51: a failed call of another session is not matched to the agent"; else fail "other session: $out"; fi
rm -f "$LOG"
A_start dev $A1 0; A_fin dev $A1 1; A_start dev $A1 2; A_fin dev $A1 4
run '' summary
if has_line "$(ag dev 1 0 0 0 0 0 0 0)" && has_line "Agent run time: dev total 180 s, average 180 s over 1 run"; then pass "AC8/AC51: one agent code started and finished twice: one run, one summed run time"; else fail "code used twice: $out"; fi
rm -f "$LOG"
A_start dev $A1 0; A_fin dev $A1 1; A_fin dev $A1 1
run '' summary
if has_line "$(ag dev 1 0 0 0 0 0 0 0)"; then pass "AC51: two finish lines of one agent code are one run"; else fail "two finish lines: $out"; fi
rm -f "$LOG"
# internal agents (empty type) and other plugins' agents write no line; one that does appear in a log is not counted
A_start CANARY_AGENT $A1 0; A_fin CANARY_AGENT $A1 1; A_start "" $A2 0; A_fin "" $A2 1; A_fin general-purpose $A3 1
run '' summary
if has_line "No usage recorded in the last 30 days." && ! printf '%s\n' "$out$err" | grep -q CANARY; then pass "AC13/AC51: internal and non-own agents are ignored"; else fail "non-own agents: $out"; fi
rm -f "$LOG"
# the same merge when the failed line does carry the agent code: verdict still counted once
A_start qa $A1 0; adds 1 1 "\"kind\":\"agent\",\"name\":\"qa\",\"result\":\"ok\",\"agent\":\"$A1\",\"verdict\":\"PASS\""; add 1 "\"kind\":\"agent\",\"name\":\"qa\",\"result\":\"failed\",\"call\":\"$C1\",\"agent\":\"$A1\""
run '' summary
if has_line "Verdicts: PASS 1" && has_line "$(ag qa 1 1 0 0 0 0 0 0)"; then pass "AC51: a failed call line that does carry the agent code adds no second run and no second verdict"; else fail "verdict once: $out"; fi
rm -f "$LOG"
L_call agent dev $C1; L_ask agent dev $C1; A_start dev $A1 0; A_fin dev $A1 1; L_launch $C1
run '' summary
case "$out$err" in *agentcode*|*callcode*|*sesscode*) fail "AC27: summary printed a code: $out";; *) pass "AC27: session, agent and call codes are never printed";; esac
rm -f "$LOG"

# session length (AC12): start paired with the next end of the same code in file order
rm -f "$LOG"
adds 5 0 '"kind":"start","session":"aaaaaaaaaaaa"'      # overlapping sessions A and B, file order interleaved
adds 5 10 '"kind":"start","session":"bbbbbbbbbbbb"'
adds 5 30 '"kind":"end","session":"aaaaaaaaaaaa"'         # A = 30 min
adds 5 70 '"kind":"end","session":"bbbbbbbbbbbb"'         # B = 60 min
adds 4 0 '"kind":"start","session":"cccccccccccc"'        # /clear keeping the code: start, start, end
adds 4 5 '"kind":"start","session":"cccccccccccc"'
adds 4 20 '"kind":"end","session":"cccccccccccc"'         # C = 20 min (the earlier start); the second start has no end
adds 3 0 '"kind":"start","session":"dddddddddddd"'        # /clear changing the code: end of the old, start of the new
adds 3 40 '"kind":"end","session":"dddddddddddd"'         # D1 = 40 min
adds 3 40 '"kind":"start","session":"eeeeeeeeeeee"'
adds 3 100 '"kind":"end","session":"eeeeeeeeeeee"'        # D2 = 60 min
adds 2 0 '"kind":"start","session":"ffffffffffff"'        # killed session: no end
adds 2 0 '"kind":"start"'                                  # no code: never paired
adds 2 60 '"kind":"end"'
adds 1 50 '"kind":"start","session":"gggggggggggg"'       # clock set back: end before start
adds 1 10 '"kind":"end","session":"gggggggggggg"'
python3 - "$LOG" "$NOW0" <<'PY'
import sys, time
path, now = sys.argv[1], int(sys.argv[2])
def t(m): return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now - 30 * 86400 + m * 60))
with open(path, "a") as f:  # start 10 min before the 30-day cut-off, end 10 min after it
    f.write('{"time":"%s","kind":"start","session":"hhhhhhhhhhhh"}\n{"time":"%s","kind":"end","session":"hhhhhhhhhhhh"}\n' % (t(-10), t(10)))
PY
run '' summary
has_line "Session length: total 3:30 h, average 42 min over 5 sessions" && pass "session length: overlap, same-code /clear, new-code /clear; killed, no-code, clock-back and cut-off starts are not counted" || fail "session length: $out"
run '' summary --days 90
has_line "Session length: total 3:50 h, average 38 min over 6 sessions" && pass "session length: --days 90 pairs the start that the 30-day period cut off" || fail "session length 90: $out"
for bad in aaaaaaaaaaaa bbbbbbbbbbbb cccccccccccc dddddddddddd eeeeeeeeeeee ffffffffffff gggggggggggg hhhhhhhhhhhh; do
  case "$out$err" in *"$bad"*) fail "summary printed a session code: $bad";; *) pass "summary never prints session code $bad";; esac
done
rm -f "$LOG"; adds 1 0 '"kind":"start","session":"aaaaaaaaaaaa"'; add 1 '"kind":"skill","name":"tdd","result":"ok"'
run '' summary
has_line "Session length: no session has a length" && pass "session length: only an open start gives no length and no failure" || fail "open start only: $out"

# bounded read: a log of many megabytes still finishes at once and counts its tail
rm -f "$LOG"
python3 - "$LOG" "$(ts 1)" <<'PY'
import sys
path, t = sys.argv[1], sys.argv[2]
with open(path, "w") as f:
    line = '{"time":"%s","kind":"skill","name":"tdd","result":"ok","version":"0.13.0","off":[]}\n' % t
    f.write(line * 400000)  # about 30 MB
PY
start=$(python3 -c 'import time;print(time.time())')
run '' summary
elapsed=$(python3 -c 'import sys,time;print(time.time()-float(sys.argv[1]))' "$start")
[ "$rc" = 0 ] && python3 -c 'import sys;sys.exit(0 if float(sys.argv[1])<5 else 1)' "$elapsed" && pass "30 MB log: summary finishes in under 5 s (read is bounded)" || fail "30 MB log: rc=$rc elapsed=$elapsed"
n=$(printf '%s\n' "$out" | sed -n 's/^  tdd: runs \([0-9]*\),.*$/\1/p')
if [ -n "$n" ] && [ "$n" -gt 0 ] && [ "$n" -lt 400000 ]; then pass "30 MB log: only the tail is read ($n of 400000 lines counted)"; else fail "30 MB log output: $out"; fi

# missing or empty log, no period lines, HOME unset
rm -f "$LOG"
run '' summary
has_line "No usage recorded in the last 30 days." && [ "$rc" = 0 ] && pass "missing log: one line says no usage recorded, exit 0" || fail "missing log: rc=$rc out=$out"
rm -rf "$HOME/.config"; before=$(snapshot); run '' summary
[ "$(snapshot)" = "$before" ] && [ ! -e "$HOME/.config" ] && pass "no-usage path writes nothing (no ~/.config created)" || fail "no-usage path changed the file tree"
mkdir -p "$LOGDIR"
: > "$LOG"
run '' summary
has_line "No usage recorded in the last 30 days." && pass "empty log: no usage recorded" || fail "empty log: $out"
add 100 '"kind":"skill","name":"tdd","result":"ok"'
run '' summary
has_line "No usage recorded in the last 30 days." && pass "only old lines: no usage recorded" || fail "only old lines: $out"
out=$(env -u HOME python3 -I "$helper" summary 2>"$work/err"); rc=$?
[ "$rc" != 0 ] && [ -z "$out" ] && grep -q 'cannot find the usage file' "$work/err" && pass "HOME unset: says it cannot find the usage file" || fail "HOME unset: rc=$rc out=$out err=$(cat "$work/err")"
rm -f "$LOG"


# ---------------------------------------------------------------- redact
# expect <name> <input> <expected output>: exact match
expect() {
  run "$2" redact
  if [ "$rc" = 0 ] && [ "$out" = "$3" ]; then pass "redact: $1"; else fail "redact: $1 (rc=$rc, got '$out', want '$3', err='$err')"; fi
}
printf 'Zebra Corp\na+b(c)\n[x]*\nacme\nfoo bar\nbar baz\n' > "$TERMS"

expect "unix path with spaces in the folder names" 'Failed at /Users/jane doe/My Project/src/app.py line 3' "Failed at $MARK line 3"
expect "unix home path" 'see /home/bob/x.txt, then' "see $MARK, then"
expect "root-level folder" 'cd /tmp/x and' "cd $MARK and"
expect "home with tilde" 'in ~/dev/proj/file.py ok' "in $MARK ok"
expect "tilde user with path" 'see ~alice/notes.txt now' "see $MARK now"
expect "tilde user alone" 'owner ~alice done' "owner $MARK done"
expect "windows path with spaces" 'open C:\Users\Jane Doe\Documents\r.txt ok' "open $MARK ok"
expect "windows path with forward slashes" 'open C:/Users/x/y.txt ok' "open $MARK ok"
expect "UNC path with spaces" 'copy \\fileserver\share\Team Docs\q.xlsx done' "copy $MARK done"
expect "file URL" 'url file:///Users/x/y.txt and' "url $MARK and"
expect "path in parentheses" 'bug (see /Users/z/q.py) here' "bug (see $MARK) here"
expect "e-mail" 'mail jane.doe+x@example.org now' "mail $MARK now"
expect "term with regex characters" 'see a+b(c) and [x]* ok' "see $MARK and $MARK ok"
expect "term is case-insensitive" 'ZEBRA corp rocks' "$MARK rocks"
expect "term inside a path" 'at /opt/acme/data/f.txt ok' "at $MARK ok"
expect "overlapping terms become one marker" 'foo bar baz end' "$MARK end"
expect "term inside a word is removed too (fixed string)" 'xacmey' "x${MARK}y"
expect "text without anything to remove is unchanged" 'TCP/IP and/or 11/18 /ordo:feedback https://example.org/a/b héllo 日本' 'TCP/IP and/or 11/18 /ordo:feedback https://example.org/a/b héllo 日本'
expect "several lines and the user's own words" $'what happened\n/Users/q/w.py broke\nmail me: a@b.co' $'what happened\n'"$MARK"$' broke\nmail me: '"$MARK"
run $'line one\r\n/Users/q/w.py end\r\n' redact
[ "$out" = $'line one\r\n'"$MARK"$' end\r' ] && pass "redact: CRLF text keeps its CR" || fail "redact: CRLF text ($(printf '%s' "$out" | od -c | head -3))"
run 'no terms here' redact
[ "$out" = 'no terms here' ] && pass "redact: usable list adds no note line" || fail "redact: unexpected note: $out"

# path boundaries: after a colon, after a flag letter, file: and scheme://file/ forms, a prefix before /Users
expect "PATH list joined by a colon" 'PATH=/usr/bin:/Users/jane/bin ok' "PATH=$MARK:$MARK ok"
expect "path after error:" 'error:/Users/jane/x.py bad' "error:$MARK bad"
expect "path glued to a compiler flag" 'clang -I/Users/jane/include -c' "clang -I$MARK -c"
expect "file:/ URL with one slash" 'open file:/Users/jane/x.txt now' "open $MARK now"
expect "scheme://file/ URL" 'open vscode://file/Users/jane/x.py:3 now' "open $MARK now"
expect "prefix before /Users" 'see x/Users/jane/x.py now' "see x$MARK now"
expect "https URL and a slash command next to it stay" 'run /ordo:feedback https://example.org/docs/a end' 'run /ordo:feedback https://example.org/docs/a end'
expect "folder names with more words" 'at /Users/jane/One Two Three Four Five Six/file.txt end' "at $MARK end"
expect "long-path Windows prefix" 'open \\?\C:\Users\Jane Doe\x.txt ok' "open $MARK ok"
expect "closing backtick kept" 'see `/Users/jane/x.py` ok' "see \`$MARK\` ok"
expect "closing backtick kept, windows" 'see `C:\Users\jane\x.py` ok' "see \`$MARK\` ok"

# the terms list: CRLF, blanks and padding follow the list reading rules
printf 'acme\r\n\r\n  zebra  \r\n\t\r\n' > "$TERMS"
expect "CRLF list with blank and padded lines" 'acme and zebra' "$MARK and $MARK"

# marker matching a term, and running twice
printf 'removed\n' > "$TERMS"
expect "marker text matching a term" 'x removed y /a/b' "x $MARK y $MARK"
run "x $MARK y" redact
[ "$out" = "x $MARK y" ] && pass "redact: an existing marker is kept (running twice is stable)" || fail "redact twice: $out"

# the list was not used: paths and e-mail still go, one note line on stdout, exit 0
note_case() { # name
  run 'at /Users/a/b.py mail x@y.org term' redact
  if [ "$rc" = 0 ] && [ -z "$err" ] && [ "$(printf '%s\n' "$out" | sed -n 1p | cut -c1-14)" = 'ordo-redact-no' ] \
     && [ "$(printf '%s\n' "$out" | sed -n 2p)" = "at $MARK mail $MARK term" ] && [ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" = 2 ]; then
    pass "redact: $1: note line first, text redacted, exit 0"
  else fail "redact: $1: rc=$rc err='$err' out='$out'"; fi
}
rm -f "$TERMS"; note_case "missing list"
: > "$TERMS"; note_case "empty list"
printf '\r\n  \n' > "$TERMS"; note_case "list of blank lines only"
printf 'te\000rm\n' > "$TERMS"; note_case "list with a NUL byte"
printf 'ok\n\xff\xfeterm\n' > "$TERMS"; note_case "list that is not UTF-8"
rm -f "$TERMS"; mkdir "$TERMS"; note_case "list that is a directory"; rmdir "$TERMS"
printf 'term\n' > "$TERMS"; chmod 000 "$TERMS"; note_case "unreadable list"; chmod 600 "$TERMS"
out=$(env -u HOME sh -c 'printf "at /Users/a/b.py ok" | python3 -I "$0" redact 2>&2' "$helper" 2>"$work/err"); rc=$?
[ "$rc" = 0 ] && [ "$(printf '%s\n' "$out" | sed -n 2p)" = "at $MARK ok" ] && pass "redact: HOME unset still removes paths" || fail "redact HOME unset: rc=$rc out=$out"
rm -f "$TERMS"
before=$(snapshot)
run 'x /a/b' redact
[ "$(snapshot)" = "$before" ] && pass "redact writes nothing" || fail "redact changed the file tree"


# ---------------------------------------------------------------- switch (usage_log, same rules as the hook)
proj="$work/proj"; mkdir -p "$proj"
sw() { out=$(cd "$proj" && printf '' | python3 -I "$helper" switch "$@" 2>"$work/err"; echo "rc=$?"); rc=${out##*rc=}; out=${out%rc=*}; out=${out%$'\n'}; err=$(cat "$work/err"); }
rm -f "$proj/CLAUDE.md" "$HOME/.claude/CLAUDE.md"; sw
[ "$rc" = 0 ] && [ "$out" = "usage_log: off" ] && pass "switch: no line means off" || fail "switch none: rc=$rc out=$out"
printf 'ordo usage_log: on\n' > "$HOME/.claude/CLAUDE.md"; sw
[ "$out" = "usage_log: on" ] && pass "switch: global on" || fail "switch global: $out"
printf 'x\r\n  ordo usage_log: off  \r\n' > "$proj/CLAUDE.md"; sw
[ "$out" = "usage_log: off" ] && pass "switch: project off beats global on (CRLF and padding allowed)" || fail "switch project: $out"
printf 'ordo usage_log: off\nordo usage_log: on\n' > "$proj/CLAUDE.md"; sw
[ "$out" = "usage_log: on" ] && pass "switch: the last valid line in a file wins" || fail "switch last line: $out"
printf 'ordo usage_log: ON\n- ordo usage_log: on\n' > "$proj/CLAUDE.md"; printf 'ordo usage_log: off\n' > "$HOME/.claude/CLAUDE.md"; sw
[ "$out" = "usage_log: off" ] && pass "switch: upper case and bullet lines are ignored" || fail "switch junk lines: $out"
before=$(snapshot); sw; [ "$(snapshot)" = "$before" ] && pass "switch writes nothing" || fail "switch changed files"
rm -f "$proj/CLAUDE.md" "$HOME/.claude/CLAUDE.md"; rm -rf "$LOGDIR"; mkdir -p "$LOGDIR"

# ---------------------------------------------------------------- settings (AC52): all 13 switches and the 10 value settings, with their level
ST="$work/st"; mkdir -p "$ST"
stg() { out=$(cd "$ST" && printf '' | python3 -I "$helper" settings "$@" 2>"$work/err"; echo "rc=$?"); rc=${out##*rc=}; out=${out%rc=*}; out=${out%$'\n'}; err=$(cat "$work/err"); }
# want <key> <value> <level>: the line '- key: value (level)' is in the output
want() { if has_line "- $1: $2 ($3)"; then pass "settings: $1 is $2 ($3)"; else fail "settings: want '- $1: $2 ($3)': $out"; fi; }
reset_st() { rm -rf "$ST/CLAUDE.md" "$HOME/.claude/CLAUDE.md" "$HOME/CLAUDE.md"; }
reset_st; stg
if [ "$rc" = 0 ] && [ -z "$err" ] && [ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" = 23 ]; then pass "settings: 23 lines (13 switches and 10 values), exit 0"; else fail "settings count: rc=$rc err=$err out=$out"; fi
for k in guard_hook git_rules eval_budget dev_helper_tier1 dev_helper_tier2 code_review_tier1 code_review_tier2 plan_review qa_check po_acceptance_tier1 po_acceptance_tier2 stall_watch; do want $k on default; done
want usage_log off default
want watch_check_minutes 5 default; want watch_report_minutes 10 default; want watch_check_by script default
want reader_threshold_tokens 200000 default; want reader_threshold_files 10 default; want reader_cap_tokens 80000 default; want reader_cap_files 10 default
want addon_max_lines 40 default; want addon_scope global default; want domain_skills none default
reset_st
printf 'ordo guard_hook: off\nordo usage_log: on\nordo watch_check_minutes: 7\nordo reader_cap_files: 3\n' > "$HOME/.claude/CLAUDE.md"; stg
want guard_hook off global; want usage_log on global; want watch_check_minutes 7 global; want reader_cap_files 3 global; want qa_check on default
printf 'ordo guard_hook: on\nordo watch_check_by: model\nordo reader_cap_files: 9\n' > "$ST/CLAUDE.md"; stg
want guard_hook on project; want usage_log on global; want watch_check_by model project; want reader_cap_files 9 project; want watch_check_minutes 7 global
printf 'ordo guard_hook: off\nordo guard_hook: on\nordo watch_check_minutes: 3\nordo watch_check_minutes: 4\nordo watch_check_by: model\nordo watch_check_by: script\n' > "$ST/CLAUDE.md"; stg
want guard_hook on project; want watch_check_minutes 4 project; want watch_check_by script project
printf 'ordo guard_hook: off\nordo guard_hook: maybe\nordo watch_check_minutes: 4\nordo watch_check_minutes: 0\nordo watch_check_minutes: -3\nordo watch_check_minutes: 4.5\nordo watch_check_minutes: abc\nordo watch_check_minutes:\nordo watch_check_by: perl\nordo reader_cap_tokens: 12 \n' > "$ST/CLAUDE.md"; stg
want guard_hook off project; want watch_check_minutes 4 project; want watch_check_by script default; want reader_cap_tokens 12 project
printf 'ordo guard_hook: ON\n- ordo qa_check: off\nordo qa_check: off now\nordo  qa_check: off\nordo unknown_key: 5\nordo watch_check_minutes: 9 extra\nordo reader_cap_files: 0x10\nordo reader_cap_tokens: +5\n' > "$ST/CLAUDE.md"; stg
want guard_hook off global; want qa_check on default; want watch_check_minutes 7 global; want reader_cap_files 3 global; want reader_cap_tokens 80000 default
printf 'ordo stall_watch: off\r\n  ordo qa_check: off  \r\nordo watch_check_minutes: 6\r\nordo reader_cap_files: 02\r\n' > "$ST/CLAUDE.md"; stg
want stall_watch off project; want qa_check off project; want watch_check_minutes 6 project; want reader_cap_files 2 project
# add-on settings (AC8, AC9, AC12): project beats global; an invalid value falls back to the next level or the default
printf 'ordo addon_max_lines: 25\nordo addon_scope: ask\n' > "$HOME/.claude/CLAUDE.md"; stg
want addon_max_lines 25 global; want addon_scope ask global
printf 'ordo addon_max_lines: 60\nordo addon_scope: project\n' > "$ST/CLAUDE.md"; stg
want addon_max_lines 60 project; want addon_scope project project
printf 'ordo addon_max_lines: 0\nordo addon_scope: both\n' > "$ST/CLAUDE.md"; stg
want addon_max_lines 25 global; want addon_scope ask global
printf 'ordo addon_max_lines: abc\nordo addon_scope: both\n' > "$ST/CLAUDE.md"; rm -f "$HOME/.claude/CLAUDE.md"; stg
want addon_max_lines 40 default; want addon_scope global default
printf 'ordo guard_hook: off\nordo usage_log: on\nordo watch_check_minutes: 7\nordo reader_cap_files: 3\n' > "$HOME/.claude/CLAUDE.md"; rm -f "$ST/CLAUDE.md"
# a project value that is invalid does not hide the global one; a missing, unreadable, non-UTF-8, over-1-MB or non-regular file is silent for its level
rm -f "$ST/CLAUDE.md"; mkdir "$ST/CLAUDE.md"; stg
want guard_hook off global; want watch_check_minutes 7 global; rmdir "$ST/CLAUDE.md"
printf 'ordo guard_hook: on\n\xff\xfe\n' > "$ST/CLAUDE.md"; stg
want guard_hook off global; rm -f "$ST/CLAUDE.md"
python3 - "$ST/CLAUDE.md" <<'PY'
import sys
open(sys.argv[1], "w").write("ordo guard_hook: on\n" + "x" * (1 << 20) + "\n")
PY
stg; want guard_hook off global; rm -f "$ST/CLAUDE.md"
printf 'ordo guard_hook: on\n' > "$ST/CLAUDE.md"; chmod 000 "$ST/CLAUDE.md"; stg; want guard_hook off global; chmod 600 "$ST/CLAUDE.md"; rm -f "$ST/CLAUDE.md"
rm -f "$HOME/.claude/CLAUDE.md"; stg
want guard_hook on default; want watch_check_minutes 5 default
# the global file alone, the project file alone, and the same project file also read as the global one when the project is HOME
printf 'ordo plan_review: off\n' > "$HOME/.claude/CLAUDE.md"; stg; want plan_review off global
rm -f "$HOME/.claude/CLAUDE.md"; printf 'ordo plan_review: off\n' > "$ST/CLAUDE.md"; stg; want plan_review off project
# no path is ever printed; level names only
printf 'ordo plan_review: off\nordo reader_cap_files: 3\n' > "$ST/CLAUDE.md"; printf 'ordo qa_check: off\n' > "$HOME/.claude/CLAUDE.md"; stg
case "$out$err" in *"$work"*|*"$HOME"*|*"/"*|*"CLAUDE.md"*) fail "settings printed a path or a file name: $out";; *) pass "settings: no path and no file name in the output";; esac
if ! printf '%s\n' "$out" | grep -vE '^- [a-z_0-9]+: [a-z0-9]+ \((project|global|default)\)$' | grep -q .; then pass "settings: every line is '- key: value (project|global|default)'"; else fail "settings: odd line: $out"; fi
before=$(snapshot); stg; [ "$(snapshot)" = "$before" ] && pass "settings writes nothing" || fail "settings changed the file tree"
stg extra; [ "$rc" != 0 ] && pass "settings takes no argument" || fail "settings accepted an argument"
reset_st
# domain_skills (AC7, AC8, AC18): a comma list; the line shows only set or none, never the names
CAN=canary-skill-7f3e
dsk() { # <project file text or -> <global file text or -> <value> <level>
  reset_st
  [ "$1" = - ] || printf -- "$1" > "$ST/CLAUDE.md"
  [ "$2" = - ] || printf -- "$2" > "$HOME/.claude/CLAUDE.md"
  stg; want domain_skills "$3" "$4"
  case "$out$err" in *canary*|*acme*) fail "domain_skills: a skill name was printed: $out$err";; *) pass "domain_skills: no skill name in stdout or stderr";; esac
}
dsk "ordo domain_skills: $CAN\n" - set project
dsk - "ordo domain_skills: $CAN\n" set global
dsk "ordo domain_skills: $CAN\n" "ordo domain_skills: acme:other\n" set project
dsk "ordo domain_skills: acme:a\nordo domain_skills: $CAN\n" - set project
dsk "ordo domain_skills: $CAN\nordo domain_skills: a,,b\n" - set project   # last line invalid: the earlier valid one stays
dsk "ordo domain_skills: a,,b\nordo domain_skills: $CAN\n" - set project
dsk "ordo domain_skills: $CAN , acme:b\t,\tacme:c\n" - set project
dsk "ordo domain_skills: $CAN,acme:b,\n" - none default
dsk "ordo domain_skills: $CAN,,acme:b\n" - none default
dsk "ordo domain_skills: ,$CAN\n" - none default
dsk "ordo domain_skills: $CAN acme:b\n" - none default
dsk "ordo domain_skills: acme:a, acme b\n" - none default
dsk "ordo domain_skills: ,\n" - none default
dsk "ordo domain_skills: acme:a\xc2\xa0acme:b\n" - none default   # no-break space inside a name
dsk "ordo domain_skills: acme:a,acme:b\xe3\x80\x80acme:c\n" - none default   # ideographic space inside a name
dsk "ordo domain_skills:\n" - none default
dsk "ordo domain_skills:  \n" - none default
dsk "ordo domain_skills: $CAN,\n" "ordo domain_skills: acme:g\n" set global
dsk "ordo domain_skills: $CAN,,x\n" "ordo domain_skills: acme:g,\n" none default
dsk "- ordo domain_skills: $CAN\nORDO domain_skills: $CAN\n" - none default
reset_st
# the project dir is the cwd: another cwd gives another answer
mkdir -p "$ST/other"; printf 'ordo plan_review: off\n' > "$ST/CLAUDE.md"
out=$(cd "$ST/other" && python3 -I "$helper" settings 2>&1); has_line "- plan_review: on (default)" && pass "settings: the cwd decides the project level" || fail "settings cwd: $out"
reset_st

# ---------------------------------------------------------------- clear
mklog3() { rm -rf "$LOGDIR"; mkdir -p "$LOGDIR"; add 10 '"kind":"skill","name":"tdd"'; add 5 '"kind":"agent","name":"dev","seconds":3'; add 2 '"kind":"guard","family":"rebase"'
  printf 'dummy terms\n' > "$TERMS"; printf 'keep me\n' > "$LOGDIR/other.txt"; printf 'ordo usage_log: on\n' > "$HOME/.claude/CLAUDE.md"; }
mklog3
first=$(sed -n 's/.*"time":"\([^"]*\)".*/\1/p' "$LOG" | sort | head -1); last=$(sed -n 's/.*"time":"\([^"]*\)".*/\1/p' "$LOG" | sort | tail -1)
run '' clear-info
if [ "$rc" = 0 ] && has_line "File: $LOG" && has_line "Lines: 3" && has_line "Period: $first to $last"; then pass "clear-info shows the path, the line count and the period"; else fail "clear-info: rc=$rc out=$out"; fi
[ -f "$LOG" ] && pass "clear-info deletes nothing" || fail "clear-info deleted the log"
before=$(snapshot); run '' clear-info; [ "$(snapshot)" = "$before" ] && pass "clear-info writes nothing" || fail "clear-info changed files"

for args in "clear" "clear --no" "clear yes" "clear --yes extra" "clear --YES"; do
  mklog3; run '' $args
  if [ "$rc" != 0 ] && [ -f "$LOG" ] && [ "$(wc -l < "$LOG" | tr -d ' ')" = 3 ]; then pass "'$args' deletes nothing (rc=$rc)"; else fail "'$args': rc=$rc, log present: $([ -f "$LOG" ] && echo yes || echo no)"; fi
done
mklog3; run '' clear-info --yes
[ "$rc" != 0 ] && [ -f "$LOG" ] && pass "clear-info --yes is refused and deletes nothing" || fail "clear-info --yes: rc=$rc"

mklog3
run '' clear --yes
if [ "$rc" = 0 ] && [ ! -e "$LOG" ] && [ -f "$TERMS" ] && [ -f "$LOGDIR/other.txt" ] && [ -f "$HOME/.claude/CLAUDE.md" ] && [ -d "$LOGDIR" ]; then
  pass "clear --yes removes usage.jsonl only (terms list, other files, CLAUDE.md and the directory stay)"
else fail "clear --yes: rc=$rc out=$out"; fi
[ "$(cat "$LOGDIR/other.txt")" = "keep me" ] && [ "$(cat "$TERMS")" = "dummy terms" ] && pass "clear --yes left other files unchanged" || fail "clear --yes changed another file"
run '' clear-info
has_line "Nothing to delete: $LOG is missing or empty." && [ "$rc" = 0 ] && pass "clear-info on a missing log says nothing to delete" || fail "clear-info missing: rc=$rc out=$out"
run '' clear --yes
[ "$rc" = 0 ] && has_line "Nothing to delete: $LOG is missing or empty." && pass "clear --yes on a missing log says nothing to delete" || fail "clear --yes missing: rc=$rc out=$out"
mklog3; : > "$LOG"; run '' clear-info
has_line "Nothing to delete: $LOG is missing or empty." && pass "clear-info on an empty log says nothing to delete" || fail "clear-info empty: $out"

# a symlink or a directory at that path is refused and left alone
mklog3; rm -f "$LOG"; printf 'target\n' > "$LOGDIR/target.txt"; ln -s "$LOGDIR/target.txt" "$LOG"
run '' clear --yes
[ "$rc" != 0 ] && [ -L "$LOG" ] && [ "$(cat "$LOGDIR/target.txt")" = "target" ] && pass "clear --yes refuses a symlink and touches neither it nor its target" || fail "clear --yes symlink: rc=$rc"
mklog3; rm -f "$LOG"; mkdir "$LOG"; printf 'x\n' > "$LOG/inner.txt"
run '' clear --yes
[ "$rc" != 0 ] && [ -f "$LOG/inner.txt" ] && pass "clear --yes refuses a directory named usage.jsonl" || fail "clear --yes directory: rc=$rc"
rm -rf "$LOG"
mklog3; chmod 500 "$LOGDIR"; run '' clear --yes; chmod 700 "$LOGDIR"
if [ "$rc" != 0 ] && [ -f "$LOG" ] && [ "$(printf '%s\n' "$err" | wc -l | tr -d ' ')" = 1 ] && ! printf '%s' "$err" | grep -q Traceback; then pass "clear --yes with an undeletable file: one-line error, no traceback, file stays"; else fail "clear unwritable: rc=$rc err=$err"; fi
out=$(env -u HOME python3 -I "$helper" clear --yes 2>"$work/err"); rc=$?
[ "$rc" != 0 ] && grep -q 'cannot find the usage file' "$work/err" && pass "clear with HOME unset: cannot find the usage file" || fail "clear HOME unset: rc=$rc"
run '' bogus; [ "$rc" != 0 ] && pass "unknown command is refused" || fail "unknown command accepted"
run '' ; [ "$rc" != 0 ] && pass "no command is refused" || fail "no command accepted"

# ---------------------------------------------------------------- source and repo greps
if grep -nE '\b(socket|http|urllib|requests|subprocess|importlib|ftplib|smtplib|ssl|asyncio|ctypes|shutil|pty)\b|os\.(system|popen|exec[a-z]*|spawn[a-z]*|fork)|__import__|\b(eval|exec)\(' "$helper" >"$work/ban"; then
  fail "helper source names a banned module or call: $(head -3 "$work/ban" | tr '\n' ' ')"
else pass "helper source names no network module, subprocess, exec, eval or __import__"; fi
# the ban check itself can fail: a planted import is caught
printf 'import subprocess\n' > "$work/planted.py"
grep -qE '\b(socket|http|urllib|requests|subprocess|importlib)\b' "$work/planted.py" && pass "ban pattern catches a planted subprocess import" || fail "ban pattern misses a planted import"

# F1 (security): the documented send command must not evaluate a hostile title, in any shell
skill=$root/plugins/ordo/skills/feedback/SKILL.md
cmd=$(awk '/^## Send/{p=1;next} /^## /{p=0} p && /^ *gh issue create /{sub(/^ +/,""); print; exit}' "$skill")
if [ -z "$cmd" ]; then fail "F1: no 'gh issue create' command line in the Send section"; else
  sendtmp=$work/send; mkdir -p "$sendtmp"
  for sh in /bin/bash zsh; do
    command -v "$sh" >/dev/null 2>&1 || { fail "F1: $sh not found"; continue; }
    n=0
    for t in "it's ( \"x\"" ':) $(touch PWNED)' 'back `touch PWNED` tick' '$(touch PWNED); "$(touch PWNED)"' 'plain title'; do
      n=$((n + 1)); d=$sendtmp/$n; mkdir -p "$d/cwd"; printf '%s' "$t" > "$d/title"; printf 'body $(touch PWNED)\n' > "$d/body"
      got=$(cd "$d/cwd" && DIR=$d "$sh" -c 'gh() { printf "%s" "$6" > "$DIR/got"; }; dir=$DIR; repo=o/r; '"$cmd" 2>&1)
      if [ -z "$got" ] && [ "$(cat "$d/got" 2>/dev/null)" = "$t" ] && [ -z "$(find "$d" -name PWNED)" ]; then pass "F1 $sh: title $n passed unchanged, nothing executed"
      else fail "F1 $sh: title $n got [$(cat "$d/got" 2>/dev/null)] out [$got] pwned [$(find "$d" -name PWNED)]"; fi
    done
  done
fi

echo "fails=$fails"
[ "$fails" -eq 0 ]
