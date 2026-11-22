#!/bin/bash
# Tests for plugins/ordo/hooks/usage_log.py (opt-in local usage log). Free: temp HOME, piped dummy payloads, no network, no Claude run.
# Seam: hook stdin + a temp HOME -> stdout, stderr, exit code and ~/.config/ordo/usage.jsonl. Set USAGE_LOG=<path> to test another script.
set -u

root=$(cd "$(dirname "$0")/.." && pwd)
hook=${USAGE_LOG:-$root/plugins/ordo/hooks/usage_log.py}
tmp_root=${TMPDIR:-/tmp}
tmp_root=${tmp_root%/}
work=$(mktemp -d "$tmp_root/usage-test.XXXXXX")
cleanup() {
  if [ -n "${work:-}" ] && [ -d "$work" ] && [ "${work#"$tmp_root"/}" != "$work" ]; then
    chmod -R u+rwx "$work" 2>/dev/null || true
    rm -r "$work"
  fi
}
trap cleanup EXIT

command -v jq >/dev/null || { echo "jq is required" >&2; exit 2; }
command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 2; }

export CLAUDE_PLUGIN_ROOT="$root/plugins/ordo"
PR="$root/plugins/ordo"
export HOME="$work/home"
mkdir -p "$HOME/.claude"
GLOBAL="$HOME/.claude/CLAUDE.md"
LOGDIR="$HOME/.config/ordo"
LOG="$LOGDIR/usage.jsonl"
proj="$work/proj"
mkdir -p "$proj"

fails=0
pass() { echo "ok   - $1"; }
fail() { echo "FAIL - $1"; fails=$((fails + 1)); }

# fire <payload-json>: runs the hook (cwd = process cwd $proj); sets out, err, rc
fire() {
  out=$(cd "$proj" && { printf '%s' "$1" 2>/dev/null; } | python3 "$hook" 2>"$work/err") && rc=0 || rc=$?
  err=$(cat "$work/err")
}
# quiet: last fire exited 0 with empty stdout and stderr
quiet() { [ "$rc" = 0 ] && [ -z "$out" ] && [ -z "$err" ]; }
nlines() { if [ -f "$LOG" ]; then wc -l < "$LOG" | tr -d ' '; else echo 0; fi; }
reset_log() { rm -rf "$HOME/.config"; }
set_proj() { printf -- "$1" > "$proj/CLAUDE.md"; }
set_global() { printf -- "$1" > "$GLOBAL"; }
clear_switches() { rm -f "$proj/CLAUDE.md" "$GLOBAL"; }
sha12() { printf '%s' "$1" | shasum -a 256 | cut -c1-12; }
mode_of() { python3 -c 'import os,sys;print(oct(os.stat(sys.argv[1]).st_mode & 0o777)[2:])' "$1"; }

skill_payload() { jq -nc --arg s "$1" --arg sid "${2-sid-one}" --arg cwd "$proj" '{hook_event_name:"PostToolUse",tool_name:"Skill",tool_input:{skill:$s},tool_response:{success:true,commandName:$s},cwd:$cwd,session_id:$sid}'; }
start_payload() { jq -nc --arg src "$1" --arg sid "${2-sid-one}" --arg cwd "$proj" '{hook_event_name:"SessionStart",source:$src,cwd:$cwd,session_id:$sid}'; }
end_payload() { jq -nc --arg sid "${1-sid-one}" --arg cwd "$proj" '{hook_event_name:"SessionEnd",reason:"other",cwd:$cwd,session_id:$sid}'; }

# tp <event> <tool> <tool_input-json> [extra-json]: a hook payload; session id from $SID (default sid-one)
tp() {
  local extra=${4:-'{}'}
  jq -nc --arg ev "$1" --arg tool "$2" --argjson inp "$3" --argjson extra "$extra" --arg cwd "$proj" --arg sid "${SID-sid-one}" \
    '{hook_event_name:$ev,tool_name:$tool,tool_input:$inp,cwd:$cwd,session_id:$sid,tool_use_id:"toolu_CANARY_tu",permission_mode:"default"}
     | if $ev == "PermissionRequest" then del(.tool_use_id) else . end | . + $extra'
}
# last_line_is <jq-assertion>: the log holds exactly one line and the assertion holds for it; the hook was quiet
one_line() { quiet && [ "$(nlines)" = 1 ] && jq -e "$1" "$LOG" >/dev/null 2>&1; }
# call_code <session-id> <tool> <input-json>: the documented one-way code (sha-256 of session, tool and sorted compact input, first 12 hex)
call_code() { printf '%s\n%s\n%s' "$1" "$2" "$(printf '%s' "$3" | jq -S -c .)" | shasum -a 256 | cut -c1-12; }

# validate_log <file>: every line's keys from the allowed list per kind, every value matching its pattern (AC14)
validate_log() {
  python3 -I - "$1" "$root/plugins/ordo" <<'PY'
import json, os, re, sys
log, plugin = sys.argv[1], sys.argv[2]
skills = {d for d in os.listdir(plugin + "/skills") if os.path.isfile(plugin + "/skills/%s/SKILL.md" % d)}
agents = {f[:-3] for f in os.listdir(plugin + "/agents") if f.endswith(".md")}
keys = {"skill": ({"time", "kind", "name", "result", "version", "off"}, {"session", "call"}),
        "agent": ({"time", "kind", "name", "result", "version", "off"}, {"session", "call", "agent", "verdict"}),
        "agent-start": ({"time", "kind", "name", "agent"}, {"session"}),
        "launch": ({"time", "kind"}, {"session", "call", "agent", "round"}),
        "script": ({"time", "kind", "name", "result", "version", "off"}, {"session", "call", "via"}),
        "ask": ({"time", "kind", "target", "name", "version", "off"}, {"session", "call"}),
        "call": ({"time", "kind", "target", "name"}, {"session", "call"}),
        "guard": ({"time", "kind", "family"}, {"session"}),
        "start": ({"time", "kind"}, {"session"}), "end": ({"time", "kind"}, {"session"})}
scripts = {"stall-check", "usage-report"}
sw = {"guard_hook", "git_rules", "eval_budget", "dev_helper_tier1", "dev_helper_tier2", "code_review_tier1",
      "code_review_tier2", "plan_review", "qa_check", "po_acceptance_tier1", "po_acceptance_tier2", "stall_watch"}
verdicts = {"APPROVED", "CHANGES", "PASS", "FAIL", "ACCEPTED", "REJECTED", "ESCALATE"}
bad = []
n = 0
for raw in open(log, encoding="utf-8"):
    n += 1
    o = json.loads(raw)
    k = o.get("kind")
    if k not in keys:
        bad.append((n, "kind", k)); continue
    req, opt = keys[k]
    if not (req <= set(o) <= req | opt):
        bad.append((n, "keys", sorted(o)))
    if not re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ", str(o.get("time"))): bad.append((n, "time"))
    pool = {"skill": skills, "agent": agents, "agent-start": agents, "script": scripts}.get(k)
    if k in ("ask", "call"):
        if o.get("target") not in ("skill", "agent", "script"): bad.append((n, "target", o.get("target")))
        pool = {"skill": skills, "agent": agents, "script": scripts}.get(o.get("target"))
    if "name" in o and (pool is None or o["name"] not in pool): bad.append((n, "name", o["name"]))
    if "result" in o and o["result"] not in ("ok", "failed", "aborted", "denied"): bad.append((n, "result", o["result"]))
    if "version" in o and not re.fullmatch(r"\d+\.\d+\.\d+", str(o["version"])): bad.append((n, "version"))
    if "off" in o and not (isinstance(o["off"], list) and set(o["off"]) <= sw): bad.append((n, "off"))
    for c in ("session", "call", "agent"):
        if c in o and not re.fullmatch(r"[0-9a-f]{12}", str(o[c])): bad.append((n, c))
    if "round" in o and not (type(o["round"]) is int and 0 <= o["round"] <= 999): bad.append((n, "round"))
    if "verdict" in o and o["verdict"] not in verdicts: bad.append((n, "verdict"))
    if "via" in o and o["via"] != "monitor": bad.append((n, "via"))
    if "family" in o and o["family"] not in ("rebase", "pull-rebase", "force-push", "rm-recursive"): bad.append((n, "family"))
print("lines=%d bad=%s" % (n, bad))
sys.exit(1 if bad else 0)
PY
}

# ---- AC1: no switch line -> nothing written, no directory
clear_switches; reset_log
fire "$(skill_payload ordo:tdd)"
if quiet && [ ! -e "$HOME/.config" ]; then pass "AC1 no usage_log line: nothing written, no ~/.config created"; else fail "AC1 (rc=$rc out=[$out] err=[$err])"; fi

# ---- AC2: project on / global on
reset_log; set_proj 'ordo usage_log: on\n'
fire "$(skill_payload ordo:tdd)"
if quiet && [ "$(nlines)" = 1 ] && [ "$(jq -r .kind "$LOG")" = skill ] && [ "$(jq -r .name "$LOG")" = tdd ]; then pass "AC2 project on: a skill line is recorded"; else fail "AC2 project on (rc=$rc lines=$(nlines))"; fi
reset_log; clear_switches; set_global 'ordo usage_log: on\n'
fire "$(skill_payload ordo:tdd)"
[ "$(nlines)" = 1 ] && pass "AC2 global on: a skill line is recorded" || fail "AC2 global on"

# ---- AC4: project off beats global on
reset_log; set_proj 'ordo usage_log: off\n'; set_global 'ordo usage_log: on\n'
fire "$(skill_payload ordo:tdd)"
if quiet && [ ! -e "$HOME/.config" ]; then pass "AC4 project off beats global on"; else fail "AC4"; fi
# project on beats global off
set_proj 'ordo usage_log: on\n'; set_global 'ordo usage_log: off\n'
fire "$(skill_payload ordo:tdd)"
[ "$(nlines)" = 1 ] && pass "AC4 project on beats global off" || fail "AC4 project on over global off"

# ---- AC5: on, then off: no new line, file left in place
reset_log; clear_switches; set_proj 'ordo usage_log: on\n'
fire "$(skill_payload ordo:tdd)"
before=$(cat "$LOG")
set_proj 'ordo usage_log: off\n'
fire "$(skill_payload ordo:tdd)"
if quiet && [ "$(cat "$LOG")" = "$before" ]; then pass "AC5 switching off stops writing and leaves the file"; else fail "AC5"; fi

# ---- AC3: parsing rules (content -> expect on|off)
usage_case() { # name content-printf expect
  reset_log; clear_switches; printf -- "$2" > "$proj/CLAUDE.md"
  fire "$(skill_payload ordo:tdd)"
  local got=off; [ "$(nlines)" = 1 ] && got=on
  if quiet && [ "$got" = "$3" ]; then pass "AC3 $1"; else fail "AC3 $1 (want $3 got $got rc=$rc)"; fi
}
usage_case "plain on" 'ordo usage_log: on\n' on
usage_case "padding and CRLF" '  ordo usage_log: on  \r\n' on
usage_case "last valid line wins (off last)" 'ordo usage_log: on\nordo usage_log: off\n' off
usage_case "last valid line wins (on last)" 'ordo usage_log: off\nordo usage_log: on\nordo usage_log: maybe\n' on
usage_case "upper case ignored" 'ordo usage_log: ON\n' off
usage_case "bullet ignored" '- ordo usage_log: on\n' off
usage_case "prose ignored" 'please set ordo usage_log: on\n' off
usage_case "unknown key ignored" 'ordo usage_logs: on\nordo usage: on\n' off
usage_case "other value ignored" 'ordo usage_log: yes\n' off
usage_case "old prefix ignored" 'roles usage_log: on\n' off
usage_case "non-UTF-8 file is silent" 'ordo usage_log: on\n\xff\xfe\n' off
reset_log; clear_switches; mkdir "$proj/CLAUDE.md"; fire "$(skill_payload ordo:tdd)"
quiet && [ ! -e "$HOME/.config" ] && pass "AC3 CLAUDE.md is a directory: silent" || fail "AC3 directory"
rmdir "$proj/CLAUDE.md"
reset_log; { printf 'ordo usage_log: on\n'; head -c 1100000 /dev/zero | tr '\0' x; } > "$proj/CLAUDE.md"; fire "$(skill_payload ordo:tdd)"
quiet && [ ! -e "$HOME/.config" ] && pass "AC3 CLAUDE.md over 1 MB: silent" || fail "AC3 over 1 MB"
# project silent (bad) falls through to global
reset_log; clear_switches; printf 'ordo usage_log: off\n\xff\n' > "$proj/CLAUDE.md"; set_global 'ordo usage_log: on\n'
fire "$(skill_payload ordo:tdd)"
[ "$(nlines)" = 1 ] && pass "AC3 silent project level: global decides" || fail "AC3 silent project level"

# ---- AC6: session-start output of the goal hook is the same with usage_log on, off, unset
goalhook="$root/plugins/ordo/hooks/goal_context.py"
printf '## Current goal\nShip it.\n' > "$proj/ROADMAP.md"
outs=()
for v in "" "ordo usage_log: on" "ordo usage_log: off"; do
  clear_switches; printf 'ordo qa_check: off\n%s\n' "$v" > "$proj/CLAUDE.md"
  outs+=("$(cd "$proj" && printf '%s' "$(start_payload startup)" | python3 "$goalhook" 2>&1)")
done
if [ "${outs[0]}" = "${outs[1]}" ] && [ "${outs[1]}" = "${outs[2]}" ] && ! grep -q usage_log <<<"${outs[0]}" && grep -q 'switched off: qa_check' <<<"${outs[0]}"; then
  pass "AC6 session-start output identical with usage_log unset, on, off; never names usage_log"
else fail "AC6 session-start output differs"; fi
rm -f "$proj/ROADMAP.md"
keys=$(python3 -I -c 'import sys;sys.dont_write_bytecode=True;sys.path.insert(0,sys.argv[1]);import goal_context as g;print(len(g.SWITCH_KEYS),"usage_log" in g.SWITCH_KEYS)' "$root/plugins/ordo/hooks")
[ "$keys" = "12 False" ] && pass "AC6 goal_context still checks exactly 12 keys, none is usage_log" || fail "AC6 SWITCH_KEYS: $keys"

# ---- AC7/AC13: skill lines, own list only
reset_log; clear_switches; set_proj 'ordo usage_log: on\nordo qa_check: off\nordo guard_hook: off\n'; set_global 'ordo eval_budget: off\nordo plan_review: on\n'
fire "$(skill_payload ordo:tdd)"
ver=$(jq -r .version "$root/plugins/ordo/.claude-plugin/plugin.json")
if quiet && [ "$(jq -c '[.kind,.name,.version,.off,.session]' "$LOG")" = "[\"skill\",\"tdd\",\"$ver\",[\"guard_hook\",\"eval_budget\",\"qa_check\"],\"$(sha12 sid-one)\"]" ]; then
  pass "AC7 skill line: kind, name, plugin version, off keys in README order, session code"
else fail "AC7 line: $(cat "$LOG")"; fi
reset_log
for s in canary-skill-xyz ordo:canary-fake ordo:../etc tdd ordo: ordo:TDD ""; do fire "$(skill_payload "$s")"; done
fire "$(jq -nc --arg cwd "$proj" '{hook_event_name:"PreToolUse",tool_name:"Read",tool_input:{file_path:"/x/ordo:tdd"},cwd:$cwd,session_id:"s"}')"
fire "$(jq -nc --arg cwd "$proj" '{hook_event_name:"PostToolUse",tool_name:"Skill",tool_input:{skill:7},tool_response:{success:true},cwd:$cwd,session_id:"s"}')"
[ ! -e "$LOG" ] && pass "AC13 non-ordo, fake ordo:, bare, malformed skill names and other tools: nothing recorded" || fail "AC13: $(cat "$LOG")"

# AC7: result ok / failed / aborted for a Skill call (PostToolUse, PostToolUseFailure)
SK='{"skill":"ordo:tdd"}'
reset_log
fire "$(tp PostToolUse Skill "$SK" '{"tool_response":{"success":true,"commandName":"ordo:tdd"}}')"
one_line '.kind=="skill" and .name=="tdd" and .result=="ok"' && pass "AC7 PostToolUse success true: skill line, result ok" || fail "AC7 ok: $(cat "$LOG" 2>/dev/null)"
for case in 'success false|{"tool_response":{"success":false}}' 'success a string|{"tool_response":{"success":"true"}}' 'no success key|{"tool_response":{}}' 'no response|{}'; do
  reset_log; fire "$(tp PostToolUse Skill "$SK" "${case#*|}")"
  one_line '.kind=="skill" and .result=="failed"' && pass "AC7 PostToolUse [${case%%|*}]: one skill line, result failed" || fail "AC7 [${case%%|*}]: $(cat "$LOG" 2>/dev/null)"
done
for case in 'is_interrupt true|{"error":"CANARY_ERR_f1","is_interrupt":true}|aborted' 'is_interrupt false|{"error":"CANARY_ERR_f1","is_interrupt":false}|failed' 'no is_interrupt|{"error":"CANARY_ERR_f1"}|failed' 'is_interrupt a string|{"is_interrupt":"true"}|failed' 'no error, odd types|{"error":7,"is_interrupt":[1]}|failed'; do
  IFS='|' read -r label extra want <<<"$case"
  reset_log; fire "$(tp PostToolUseFailure Skill "$SK" "$extra")"
  if one_line ".kind==\"skill\" and .name==\"tdd\" and .result==\"$want\" and (has(\"is_interrupt\")|not) and (has(\"error\")|not)" && ! grep -q 'CANARY\|interrupt\|error' "$LOG"; then pass "AC7 PostToolUseFailure [$label]: one skill line, result $want, no flag or error text"; else fail "AC7 failure [$label]: $(cat "$LOG" 2>/dev/null)"; fi
done
reset_log
fire "$(tp PostToolUseFailure Skill '{"skill":"CANARY_SKILL_f2"}' '{"is_interrupt":true}')"
fire "$(tp PostToolUseFailure Skill '{"skill":"ordo:canary-fake"}' '{}')"
fire "$(tp PreToolUse Skill '{"skill":7}')"
[ ! -e "$LOG" ] && pass "AC13 failed or aborted call of a non-own skill: nothing recorded" || fail "AC13 failure non-own: $(cat "$LOG")"
reset_log; fire "$(tp PostToolUse Skill "$SK" '{"tool_response":{"success":true}}')"; fire "$(tp PostToolUse Skill "$SK" '{"tool_response":{"success":true}}' | jq -c '.session_id=""')"
[ "$(jq -c 'has("call")' "$LOG" | tr '\n' ' ')" = "true false " ] && [ "$(jq -r '.call' "$LOG" | head -1)" = "$(call_code sid-one Skill "$SK")" ] && pass "AC15 skill line carries the call code; no session ID: no call code" || fail "AC15 skill call code: $(cat "$LOG")"

# ---- AC12/AC15: start and end lines
reset_log
fire "$(start_payload startup sid-one)"; fire "$(start_payload clear sid-one)"; fire "$(start_payload clear sid-two)"
fire "$(start_payload resume sid-one)"; fire "$(start_payload compact sid-one)"; fire "$(start_payload other sid-one)"
fire "$(end_payload sid-two)"
want="start $(sha12 sid-one)
start $(sha12 sid-one)
start $(sha12 sid-two)
end $(sha12 sid-two)"
got=$(jq -r '[.kind,.session]|join(" ")' "$LOG")
[ "$got" = "$want" ] && pass "AC12 startup/clear write start lines (same or new ID), resume/compact/other none, end writes end line" || fail "AC12: [$got]"
[ "$(sha12 sid-one)" != "$(sha12 sid-two)" ] && ! grep -q 'sid-one\|sid-two' "$LOG" && pass "AC15 code is one-way, differs per ID, the ID is not stored" || fail "AC15"
reset_log
fire "$(jq -nc --arg cwd "$proj" '{hook_event_name:"SessionStart",source:"startup",cwd:$cwd}')"
fire "$(jq -nc --arg cwd "$proj" '{hook_event_name:"SessionEnd",reason:"other",cwd:$cwd,session_id:""}')"
[ "$(jq -c 'has("session")' "$LOG" | sort -u)" = false ] && [ "$(nlines)" = 2 ] && pass "AC15 no session ID: lines carry no code" || fail "AC15 missing ID"

# ---- AC14: canaries in every payload key and value never reach the log
reset_log; clear_switches; cdir="$work/CANARY_PROJECT_q1"; mkdir -p "$cdir"; printf 'ordo usage_log: on\n' > "$cdir/CLAUDE.md"
canary_fire() { # tool event extra-input
  fire "$(jq -nc --arg cwd "$cdir" --arg ev "$1" --arg tool "$2" --arg sk "$3" \
    '{hook_event_name:$ev,tool_name:$tool,cwd:$cwd,session_id:"CANARY_SESSION_q2",transcript_path:"/CANARY_TRANSCRIPT_q3/t.jsonl",prompt:"CANARY_PROMPT_q4",
      tool_input:{skill:$sk,args:"CANARY_ARGS_q5",command:"CANARY_COMMAND_q6",file_path:"/CANARY_FILE_q7.py",prompt:"CANARY_BRIEF_q8 Round 2",subagent_type:"CANARY_AGENT_q9"},
      tool_response:{success:true,commandName:"CANARY_CMD_q14",content:[{type:"text",text:"APPROVED CANARY_REPLY_q10"}],agentType:"CANARY_AGENT_q9",agentId:"CANARY_AGENTID_q15"},
      error:"CANARY_ERR_q16",reason:"CANARY_REASON_q17",is_interrupt:true,agent_id:"CANARY_AGENTID_q15",agent_type:"CANARY_AGENT_q9",last_assistant_message:"CANARY_LAST_q18",
      permission_suggestions:[{type:"addRules",rules:[{toolName:"Bash",ruleContent:"sh /CANARY_RULE_q19/stall-check.sh"}]}]}')"
}
canary_fire PostToolUse Skill ordo:tdd
canary_fire PostToolUse Skill CANARY_SKILL_q11
canary_fire PostToolUse Skill ordo:CANARY_FAKE_q12
canary_fire PreToolUse Bash ordo:tdd
canary_fire PreToolUse Skill ordo:tdd
canary_fire PostToolUse Agent ordo:tdd
for ev in PostToolUseFailure PermissionRequest PermissionDenied; do canary_fire $ev Skill ordo:tdd; canary_fire $ev Skill CANARY_SKILL_q11; canary_fire $ev Agent ordo:tdd; canary_fire $ev Bash ordo:tdd; done
canary_fire PostToolUse Bash ordo:tdd
canary_fire SubagentStart "" ordo:tdd; canary_fire SubagentStop "" ordo:tdd
fire "$(jq -nc --arg cwd "$cdir" --arg s "sh $PR/skills/workflow/stall-check.sh --transcript /CANARY_PATH_q20/t CANARY_ARG_q21" '{hook_event_name:"PermissionRequest",tool_name:"Bash",tool_input:{command:$s,description:"CANARY_DESC_q22"},cwd:$cwd,session_id:"CANARY_SESSION_q2",permission_suggestions:[{ruleContent:"CANARY_RULE_q19"}]}')"
fire "$(jq -nc --arg cwd "$cdir" --arg s "sh $PR/skills/workflow/stall-check.sh --transcript /CANARY_PATH_q20/t CANARY_ARG_q21" '{hook_event_name:"PermissionDenied",tool_name:"Bash",tool_input:{command:$s},cwd:$cwd,session_id:"CANARY_SESSION_q2",reason:"CANARY_REASON_q17"}')"
fire "$(jq -nc --arg cwd "$cdir" '{hook_event_name:"SubagentStop",agent_id:"CANARY_AGENTID_q15",agent_type:"ordo:qa",last_assistant_message:"PASS\nCANARY_LAST_q18",cwd:$cwd,session_id:"CANARY_SESSION_q2"}')"
fire "$(jq -nc --arg cwd "$cdir" '{hook_event_name:"SubagentStart",agent_id:"CANARY_AGENTID_q15",agent_type:"ordo:qa",cwd:$cwd,session_id:"CANARY_SESSION_q2"}')"
fire "$(jq -nc --arg cwd "$cdir" '{hook_event_name:"PostToolUse",tool_name:"Agent",tool_input:{prompt:"CANARY_BRIEF_q8 Round 4",subagent_type:"ordo:qa"},tool_response:{agentId:"CANARY_AGENTID_q15",status:"async_launched"},cwd:$cwd,session_id:"CANARY_SESSION_q2"}')"
fire "$(jq -nc --arg cwd "$cdir" '{hook_event_name:"SessionStart",source:"startup",cwd:$cwd,session_id:"CANARY_SESSION_q2",transcript_path:"/CANARY_TRANSCRIPT_q3"}')"
fire "$(jq -nc --arg cwd "$cdir" '{hook_event_name:"SessionEnd",reason:"CANARY_REASON_q13",cwd:$cwd,session_id:"CANARY_SESSION_q2"}')"
if [ -s "$LOG" ] && ! grep -q CANARY "$LOG" && ! grep -q CANARY_ <<<"$out$err"; then pass "AC14 no canary string anywhere in usage.jsonl ($(nlines) lines)"; else fail "AC14 canary leaked: $(grep -o 'CANARY[A-Za-z0-9_]*' "$LOG" | sort -u | tr '\n' ' ')"; fi
res=$(validate_log "$LOG") && pass "AC14 every line: allowed keys, values match their patterns ($res)" || fail "AC14 validator: $res"

# ---- agent events (AC8, AC9, AC10, AC51): SubagentStart, SubagentStop, Agent PostToolUse (launch), Agent PostToolUseFailure
# start_pl/stop_pl <agent_type> <agent_id ("" = no agent_id)> [last_assistant_message]
sub_pl() { # event type id msg
  jq -nc --arg ev "$1" --arg t "$2" --arg id "$3" --arg m "${4-}" --arg cwd "$proj" \
    '{hook_event_name:$ev,agent_id:$id,agent_type:$t,session_id:"sid-one",cwd:$cwd,transcript_path:"/CANARY_TRANSCRIPT_a0",agent_transcript_path:"/CANARY_ATRANSCRIPT_a0",permission_mode:"default"}
     + (if $ev=="SubagentStop" then {last_assistant_message:$m,stop_hook_active:false} else {} end) | if $id=="" then del(.agent_id) else . end'
}
# launch_pl <subagent_type> <brief> [foreground|background] [agentId]
launch_pl() {
  local mode=${3:-background} id=${4-AGENT-A}
  local resp='{"agentId":"'"$id"'","status":"async_launched","isAsync":true,"prompt":"CANARY_BRIEF_a1","description":"CANARY_DESC_a2","outputFile":"/CANARY_OUT_a3"}'
  [ "$mode" = foreground ] && resp='{"agentId":"'"$id"'","agentType":"'"$1"'","content":[{"type":"text","text":"CANARY_REPLY_a4\nAPPROVED"}],"status":"completed","prompt":"CANARY_BRIEF_a1"}'
  tp PostToolUse Agent "$(jq -nc --arg t "$1" --arg b "$2" '{description:"CANARY_DESC_a2",prompt:$b,subagent_type:$t}')" "$(jq -nc --argjson r "$resp" '{tool_response:$r,duration_ms:7}')"
}
reset_log; clear_switches; set_proj 'ordo usage_log: on\nordo qa_check: off\n'
fire "$(sub_pl SubagentStart ordo:qa AGENT-A)"
if one_line '.kind=="agent-start" and .name=="qa"' && [ "$(jq -c keys "$LOG")" = '["agent","kind","name","session","time"]' ] && [ "$(jq -r .agent "$LOG")" = "$(sha12 AGENT-A)" ] && [ "$(jq -r .session "$LOG")" = "$(sha12 sid-one)" ] && ! grep -q 'AGENT-A\|CANARY' "$LOG"; then
  pass "AC8 SubagentStart: agent-start line (time, name, session code, agent code), the ID is not written"
else fail "AC8 agent-start: $(cat "$LOG" 2>/dev/null)"; fi
reset_log; fire "$(sub_pl SubagentStop ordo:qa AGENT-A $'PASS\nall good CANARY_REPLY_a5')"
if one_line '.kind=="agent" and .name=="qa" and .result=="ok" and .verdict=="PASS"' && [ "$(jq -c keys "$LOG")" = '["agent","kind","name","off","result","session","time","verdict","version"]' ] && [ "$(jq -c '[.agent,.version,.off,.session]' "$LOG")" = "[\"$(sha12 AGENT-A)\",\"$ver\",[\"qa_check\"],\"$(sha12 sid-one)\"]" ] && ! grep -q 'AGENT-A\|CANARY' "$LOG"; then
  pass "AC8 SubagentStop: one agent line (name, result ok, verdict, agent code, version, off keys, session code), no reply text"
else fail "AC8 agent finish: $(cat "$LOG" 2>/dev/null)"; fi
res=$(validate_log "$LOG") && pass "agent line passes the allowed-key validator" || fail "agent line validator: $res"

stop_case() { # label type msg jq-assertion
  reset_log; fire "$(sub_pl SubagentStop "$2" AGENT-A "$3")"
  if one_line "$4"; then pass "$1"; else fail "$1: $(cat "$LOG" 2>/dev/null)"; fi
}
stop_none() { # label event type id
  reset_log; fire "$(sub_pl "$2" "$3" "$4" "r")"
  if quiet && [ ! -e "$LOG" ]; then pass "$1"; else fail "$1: $(cat "$LOG" 2>/dev/null)"; fi
}
stop_case "AC10 code-reviewer APPROVED" ordo:code-reviewer $'APPROVED\nfine' '.verdict == "APPROVED"'
stop_case "AC10 code-reviewer CHANGES with text after" ordo:code-reviewer 'CHANGES: two findings' '.verdict == "CHANGES"'
stop_case "AC10 qa FAIL" ordo:qa 'FAIL' '.verdict == "FAIL"'
stop_case "AC10 po ESCALATE" ordo:po 'ESCALATE (cut)' '.verdict == "ESCALATE"'
stop_case "AC10 po ACCEPTED" ordo:po 'ACCEPTED' '.verdict == "ACCEPTED"'
stop_case "AC10 po REJECTED" ordo:po 'REJECTED' '.verdict == "REJECTED"'
stop_case "AC10 word not allowed for that agent (qa says APPROVED)" ordo:qa 'APPROVED' 'has("verdict") | not'
stop_case "AC10 word not allowed for that agent (code-reviewer says PASS)" ordo:code-reviewer 'PASS' 'has("verdict") | not'
stop_case "AC10 dev never gets a verdict" ordo:dev 'APPROVED' 'has("verdict") | not'
stop_case "AC10 verdict only on a later line: none" ordo:qa $'summary\nPASS' 'has("verdict") | not'
stop_case "AC10 verdict glued to letters: none" ordo:qa 'PASSED' 'has("verdict") | not'
stop_case "AC10 PASS_X: none" ordo:qa 'PASS_X' 'has("verdict") | not'
stop_case "AC10 CHANGES-ONLY: none" ordo:code-reviewer 'CHANGES-ONLY' 'has("verdict") | not'
stop_case "AC10 lower case: none" ordo:qa 'pass' 'has("verdict") | not'
stop_case "AC10 heading line '## Verdict: APPROVED'" ordo:code-reviewer $'## Verdict: APPROVED\nbody' '.verdict == "APPROVED"'
stop_case "AC10 heading line '## Verdict: PASS'" ordo:qa '## Verdict: PASS' '.verdict == "PASS"'
stop_case "AC10 label line 'Verdict: PASS'" ordo:qa 'Verdict: PASS' '.verdict == "PASS"'
stop_case "AC10 bold label '**Verdict:** FAIL'" ordo:qa '**Verdict:** FAIL' '.verdict == "FAIL"'
stop_case "AC10 bold whole '**Verdict: REJECTED**'" ordo:po '**Verdict: REJECTED**' '.verdict == "REJECTED"'
stop_case "AC10 bold closing before the colon '**Verdict**: PASS'" ordo:qa '**Verdict**: PASS' '.verdict == "PASS"'
stop_case "AC10 heading without label '# ACCEPTED'" ordo:po '# ACCEPTED' '.verdict == "ACCEPTED"'
stop_case "AC10 leading blank lines are skipped" ordo:qa $'\n  \n## Verdict: FAIL\nx' '.verdict == "FAIL"'
stop_case "AC10 CRLF line ends" ordo:qa $'## Verdict: PASS\r\nbody' '.verdict == "PASS"'
stop_case "AC10 copied template line: none" ordo:qa '## Verdict: PASS | FAIL' 'has("verdict") | not'
stop_case "AC10 copied template line (po): none" ordo:po '## Verdict: ACCEPTED | REJECTED | ESCALATE' 'has("verdict") | not'
stop_case "AC10 po none: none" ordo:po '## Verdict: none' 'has("verdict") | not'
stop_case "AC10 label, word glued to letters: none" ordo:qa '## Verdict: PASSED' 'has("verdict") | not'
stop_case "AC10 label, word not allowed for agent: none" ordo:qa '## Verdict: APPROVED' 'has("verdict") | not'
stop_case "AC10 verdict on a second non-blank line: none" ordo:qa $'Summary\n## Verdict: PASS' 'has("verdict") | not'
stop_case "AC10 empty reply: agent line without verdict" ordo:qa '' '.result=="ok" and (has("verdict") | not)'
reset_log; fire "$(sub_pl SubagentStop ordo:qa AGENT-A x | jq -c '.last_assistant_message=5')"
one_line '.result=="ok" and (has("verdict")|not)' && pass "AC10 non-string reply: agent line without verdict" || fail "non-string reply: $(cat "$LOG" 2>/dev/null)"
reset_log; fire "$(sub_pl SubagentStop ordo:qa "" PASS)"
one_line '.result=="ok" and .verdict=="PASS" and (has("agent")|not)' && pass "edge: finish without agent_id is still a run, no agent code" || fail "finish without id: $(cat "$LOG" 2>/dev/null)"
stop_none "edge: start without agent_id writes nothing (it could never be paired)" SubagentStart ordo:qa ""
stop_none "AC13 internal agent, empty type: finish ignored" SubagentStop "" AGENT-I
stop_none "AC13 internal agent, empty type: start ignored" SubagentStart "" AGENT-I
stop_none "AC13 non-ordo agent finish ignored" SubagentStop CANARY_AGENT_z AGENT-I
stop_none "AC13 non-ordo agent start ignored" SubagentStart CANARY_AGENT_z AGENT-I
stop_none "AC13 other plugin's agent ignored" SubagentStop other:qa AGENT-I
stop_none "AC13 fake ordo: agent ignored" SubagentStop ordo:canary-fake AGENT-I
stop_none "AC13 bare own name (could be a user's agent) ignored" SubagentStop qa AGENT-I
reset_log; fire "$(sub_pl SubagentStop ordo:qa AGENT-A PASS | jq -c '.agent_type=[1]')"; fire "$(sub_pl SubagentStop ordo:qa AGENT-A PASS | jq -c '.agent_id=7')"
[ "$(nlines)" = 1 ] && [ "$(jq -c 'has("agent")' "$LOG")" = false ] && pass "odd types: agent_type [1] writes nothing, agent_id 7 gives no agent code" || fail "odd types: $(cat "$LOG" 2>/dev/null)"

# launch line at the Agent PostToolUse (foreground and background), never a run line (AC8, AC9, AC51)
reset_log; fire "$(launch_pl ordo:qa 'Check it. Round 2 of the review.' background)"
AI='{"description":"CANARY_DESC_a2","prompt":"Check it. Round 2 of the review.","subagent_type":"ordo:qa"}'
if one_line '.kind=="launch" and .round==2' && [ "$(jq -c keys "$LOG")" = '["agent","call","kind","round","session","time"]' ] && [ "$(jq -c '[.agent,.call,.session]' "$LOG")" = "[\"$(sha12 AGENT-A)\",\"$(call_code sid-one Agent "$AI")\",\"$(sha12 sid-one)\"]" ] && ! grep -q 'CANARY\|AGENT-A' "$LOG"; then
  pass "AC8 background launch: one launch line (time, session code, agent code from tool_response.agentId, call code, round), no agent line"
else fail "AC8 background launch: $(cat "$LOG" 2>/dev/null)"; fi
reset_log; fire "$(launch_pl ordo:code-reviewer 'Round 3' foreground)"
if one_line '.kind=="launch" and .round==3' && [ "$(jq -c keys "$LOG")" = '["agent","call","kind","round","session","time"]' ] && ! grep -q 'CANARY\|APPROVED\|AGENT-A' "$LOG"; then
  pass "AC8 foreground launch (response with content): the same launch line, no verdict, no run time, no agent line"
else fail "AC8 foreground launch: $(cat "$LOG" 2>/dev/null)"; fi
launch_case() { # label brief jq-assertion
  reset_log; fire "$(launch_pl ordo:dev "$2")"
  if one_line ".kind==\"launch\" and $3"; then pass "$1"; else fail "$1: $(cat "$LOG" 2>/dev/null)"; fi
}
launch_case "AC9 Round 123 (3 digits) is kept" 'x Round 123 y' '.round == 123'
launch_case "AC9 leading zeros normalised" 'Round 007' '.round == 7'
launch_case "AC9 4 digits: round absent" 'Round 1234' 'has("round") | not'
launch_case "AC9 no Round text: round absent" 'plain brief' 'has("round") | not'
launch_case "AC9 Round 12a is not a round" 'Round 12a' 'has("round") | not'
launch_case "AC9 lower-case round is not a round" 'round 2' 'has("round") | not'
launch_case "AC9 first Round N wins" 'Round 3 then Round 4' '.round == 3'
reset_log; fire "$(launch_pl ordo:dev 'Round 1' background "")"
one_line '.kind=="launch" and (has("agent")|not) and has("call")' && pass "edge: launch without agentId: line without agent code" || fail "launch no id: $(cat "$LOG" 2>/dev/null)"
reset_log; fire "$(launch_pl CANARY_AGENT_z 'Round 2')"; fire "$(launch_pl ordo:canary-fake 'Round 2')"; fire "$(launch_pl qa 'Round 2')"; fire "$(launch_pl '' 'Round 2')"
fire "$(tp PreToolUse Agent '{"prompt":"Round 1","subagent_type":"CANARY_AGENT_z"}')"; fire "$(tp PostToolUse Read '{"subagent_type":"ordo:po"}')"
[ ! -e "$LOG" ] && pass "AC13 launch of a non-own, fake, bare or empty agent type, other tools: nothing recorded" || fail "AC13 launch: $(cat "$LOG")"
reset_log; set_proj 'ordo usage_log: off\n'; fire "$(launch_pl ordo:qa 'Round 2')"; fire "$(sub_pl SubagentStop ordo:qa AGENT-A PASS)"; fire "$(sub_pl SubagentStart ordo:qa AGENT-A)"
quiet && [ ! -e "$HOME/.config" ] && pass "AC1/AC4 agent events obey the switch" || fail "agent events with usage_log off"
set_proj 'ordo usage_log: on\nordo qa_check: off\n'

# failed or aborted Agent call (PostToolUseFailure): one agent line with that result, name from subagent_type
AI='{"description":"d","prompt":"CANARY_BRIEF_a6 Round 2","subagent_type":"ordo:qa"}'
for case in 'failed|{"error":"CANARY_ERR_a7","is_interrupt":false}' 'aborted|{"error":"CANARY_ERR_a7","is_interrupt":true}'; do
  want=${case%%|*}; reset_log; fire "$(tp PostToolUseFailure Agent "$AI" "${case#*|}")"
  if one_line ".kind==\"agent\" and .name==\"qa\" and .result==\"$want\" and (has(\"verdict\")|not) and (has(\"agent\")|not) and (has(\"round\")|not)" && [ "$(jq -c keys "$LOG")" = '["call","kind","name","off","result","session","time","version"]' ] && [ "$(jq -r .call "$LOG")" = "$(call_code sid-one Agent "$AI")" ] && ! grep -q 'CANARY' "$LOG"; then
    pass "AC8 Agent PostToolUseFailure ($want): one agent line (name, result, call code, version, off, session), no error text"
  else fail "AC8 Agent failure ($want): $(cat "$LOG" 2>/dev/null)"; fi
done
reset_log; fire "$(tp PostToolUseFailure Agent '{"prompt":"x","subagent_type":"CANARY_AGENT_z"}' '{"is_interrupt":true}')"; fire "$(tp PostToolUseFailure Agent '{"prompt":"x","subagent_type":""}')"
[ ! -e "$LOG" ] && pass "AC13 failed Agent call with a non-own or empty subagent_type: nothing recorded" || fail "AC13 agent failure: $(cat "$LOG")"
reset_log; fire "$(tp PostToolUseFailure Agent "$AI")"; fire "$(launch_pl ordo:qa 'Round 2')"; fire "$(sub_pl SubagentStart ordo:qa AGENT-A)"; fire "$(sub_pl SubagentStop ordo:qa AGENT-A PASS)"
res=$(validate_log "$LOG") && pass "agent-family lines pass the allowed-key validator ($res)" || fail "agent family validator: $res"
reset_log; set_proj 'ordo usage_log: on\n'
fire "$(sub_pl SubagentStart ordo:qa AGENT-A)"; fire "$(launch_pl ordo:qa 'Round 1')"; fire "$(sub_pl SubagentStop ordo:qa AGENT-A PASS)"; fire "$(sub_pl SubagentStop "" AGENT-I x)"
[ "$(jq -r '.kind' "$LOG" | tr '\n' ' ')" = "agent-start launch agent " ] && [ "$(jq -r '.agent' "$LOG" | sort -u | wc -l | tr -d ' ')" = 1 ] && pass "AC51 foreground or background: start, launch, finish share one agent code; only the agent line is a run (one result line per agent)" || fail "AC51: $(cat "$LOG")"

# ---- call (PreToolUse), ask (PermissionRequest), denied (PermissionDenied), script (Post*) lines: AC47, AC48, AC50, AC53
STALL="$PR/skills/workflow/stall-check.sh"; UREP="$PR/skills/feedback/usage-report.py"
SC="$(jq -nc --arg c "sh $STALL --transcript /CANARY_PATH_s1/t.jsonl --check 60 CANARY_ARG_s2" '{command:$c,description:"CANARY_DESC_s3"}')"
AG='{"description":"CANARY_DESC_a2","prompt":"CANARY_BRIEF_k1 Round 2","subagent_type":"ordo:qa"}'
EXTRA='{"reason":"CANARY_REASON_k2","permission_suggestions":[{"type":"addRules","rules":[{"toolName":"Bash","ruleContent":"sh /CANARY_RULE_k3/stall-check.sh"}]}]}'
reset_log; clear_switches; set_proj 'ordo usage_log: on\nordo qa_check: off\n'
# target/name tables: label|tool|input|target-or-kind|name
for row in "skill|Skill|$SK|skill|tdd" "agent|Agent|$AG|agent|qa" "script|Bash|$SC|script|stall-check"; do
  IFS='|' read -r label tool inp tgt nm <<<"$row"
  code=$(call_code sid-one "$tool" "$inp")
  reset_log; fire "$(tp PreToolUse "$tool" "$inp")"
  if one_line ".kind==\"call\" and .target==\"$tgt\" and .name==\"$nm\" and .call==\"$code\"" && [ "$(jq -c keys "$LOG")" = '["call","kind","name","session","target","time"]' ] && ! grep -q 'CANARY' "$LOG"; then
    pass "AC53 PreToolUse $label: one call line (time, target, name, session code, call code), no version or off"
  else fail "AC53 call $label: $(cat "$LOG" 2>/dev/null)"; fi
  reset_log; fire "$(tp PermissionRequest "$tool" "$inp" "$EXTRA")"
  if one_line ".kind==\"ask\" and .target==\"$tgt\" and .name==\"$nm\" and .call==\"$code\"" && [ "$(jq -c keys "$LOG")" = '["call","kind","name","off","session","target","time","version"]' ] && [ "$(jq -c .off "$LOG")" = '["qa_check"]' ] && ! grep -q 'CANARY\|suggest\|reason' "$LOG"; then
    pass "AC47 PermissionRequest $label: one ask line with the same call code, version, off keys; no suggestions"
  else fail "AC47 ask $label: $(cat "$LOG" 2>/dev/null)"; fi
  reset_log; fire "$(tp PermissionDenied "$tool" "$inp" "$EXTRA")"
  if one_line ".kind==\"$tgt\" and .result==\"denied\" and .name==\"$nm\" and .call==\"$code\"" && [ "$(jq -c keys "$LOG")" = '["call","kind","name","off","result","session","time","version"]' ] && ! grep -q 'CANARY\|suggest\|reason' "$LOG"; then
    pass "AC48 PermissionDenied $label: one line, kind $tgt, result denied, same call code, no reason"
  else fail "AC48 denied $label: $(cat "$LOG" 2>/dev/null)"; fi
done
# the same call gives the same code at every event; another session, input or tool gives another code
reset_log
fire "$(tp PreToolUse Skill "$SK")"; fire "$(tp PermissionRequest Skill '{"skill":"ordo:tdd"}')"; fire "$(tp PostToolUse Skill "$SK" '{"tool_response":{"success":true}}')"
[ "$(jq -r .call "$LOG" | sort -u | wc -l | tr -d ' ')" = 1 ] && pass "AC15 call, ask and run of one call share one call code" || fail "AC15 shared code: $(jq -r .call "$LOG" | tr '\n' ' ')"
reset_log; SID=sid-two; fire "$(tp PreToolUse Skill "$SK")"; SID=sid-one; fire "$(tp PreToolUse Skill "$SK")"; fire "$(tp PreToolUse Skill '{"skill":"ordo:diagnose"}')"
fire "$(tp PreToolUse Agent '{"subagent_type":"ordo:qa","prompt":"p","description":"d"}')"; fire "$(tp PreToolUse Agent '{"description":"d","prompt":"p","subagent_type":"ordo:qa"}')"
[ "$(jq -r .call "$LOG" | sort -u | wc -l | tr -d ' ')" = 4 ] && [ "$(jq -r .call "$LOG" | sed -n '4p')" = "$(jq -r .call "$LOG" | sed -n '5p')" ] && pass "AC15 call code differs by session, input; key order does not matter" || fail "AC15 distinct codes: $(jq -r .call "$LOG" | tr '\n' ' ')"
reset_log; fire "$(tp PreToolUse Skill "$SK" | jq -c '.session_id=""')"; fire "$(tp PreToolUse Skill "$SK" | jq -c 'del(.session_id)')"; fire "$(tp PermissionRequest Skill "$SK" | jq -c 'del(.session_id)')"
[ "$(nlines)" = 3 ] && [ "$(jq -c '[has("session"),has("call")]|tojson' "$LOG" | sort -u)" = '"[false,false]"' ] && pass "AC15 no session ID: call and ask lines carry no session code and no call code" || fail "AC15 no session: $(cat "$LOG")"
reset_log; fire "$(tp PreToolUse Skill "$SK" | jq -c 'del(.tool_input)')"; fire "$(tp PreToolUse Skill '"str"')"
[ ! -e "$LOG" ] && pass "edge: no tool_input object: no skill name, nothing recorded" || fail "no tool_input: $(cat "$LOG")"

# script lines (Post*) and the own-script rule
for case in 'PostToolUse|{"tool_response":{"stdout":"CANARY_OUT_s4","interrupted":false}}|ok' 'PostToolUseFailure|{"error":"CANARY_ERR_s5","is_interrupt":false}|failed' 'PostToolUseFailure|{"error":"CANARY_ERR_s5","is_interrupt":true}|aborted'; do
  IFS='|' read -r ev extra want <<<"$case"
  reset_log; fire "$(tp "$ev" Bash "$SC" "$extra")"
  if one_line ".kind==\"script\" and .name==\"stall-check\" and .result==\"$want\" and .call==\"$(call_code sid-one Bash "$SC")\"" && [ "$(jq -c keys "$LOG")" = '["call","kind","name","off","result","session","time","version"]' ] && ! grep -q 'CANARY\|transcript\|/' "$LOG"; then
    pass "AC50 $ev [$want]: one script line, file stem only, no command, args or paths"
  else fail "AC50 $ev [$want]: $(cat "$LOG" 2>/dev/null)"; fi
done
own_case() { # label command expected-name-or-"" (the command runs through all five events)
  local label=$1 cmd=$2 want=$3 inp ev
  inp=$(jq -nc --arg c "$cmd" '{command:$c}')
  reset_log
  for ev in PreToolUse PermissionRequest PermissionDenied PostToolUse PostToolUseFailure; do fire "$(tp "$ev" Bash "$inp")"; done
  if [ -z "$want" ]; then
    [ ! -e "$LOG" ] && pass "AC50/AC13 not an own script, nothing recorded: $label" || fail "AC13 script rule: [$cmd] -> $(cat "$LOG")"
  else
    [ "$(nlines)" = 5 ] && [ "$(jq -r .name "$LOG" | sort -u)" = "$want" ] && pass "AC50 own script [$want] recognised: $label" || fail "AC50 own script [$cmd]: $(cat "$LOG" 2>/dev/null)"
  fi
}
own_case "sh <plugin>/stall-check.sh with args" "sh $STALL --transcript /x --check 60" stall-check
own_case "python3 <plugin>/usage-report.py summary" "python3 $UREP summary --days 30" usage-report
own_case "bash with an option, quoted path" "bash -e \"$STALL\"" stall-check
own_case "path run directly" "$STALL --check 1" stall-check
own_case "plain ls" "ls -la" ""
own_case "git status" "git status" ""
own_case "stall-check outside the plugin" "sh /CANARY_elsewhere/skills/workflow/stall-check.sh" ""
own_case "relative path" "sh skills/workflow/stall-check.sh" ""
own_case "own file only read (cat)" "cat $STALL" ""
own_case "own file only an argument of another script" "sh /CANARY_other.sh $STALL" ""
own_case "own name with a suffix" "sh $STALL.bak" ""
own_case "usage-report outside a skill directory" "python3 $PR/usage-report.py" ""
own_case "usage-report two levels below skills" "python3 $PR/skills/workflow/x/usage-report.py" ""
own_case "a script file of the plugin that is not on the list" "sh $PR/skills/workflow/SKILL.md" ""
own_case "pipe into an own script" "printf %s \"some text\" | python3 $UREP redact" usage-report
own_case "file piped into an own script" "cat /tmp/CANARY_d | python3 $UREP redact" usage-report
own_case "cd then own script (&&)" "cd /x && sh $STALL --check 1" stall-check
own_case "list with ; then own script" "a; python3 $UREP summary" usage-report
own_case "own script, then a pipe to head" "sh $STALL --check 1 2>&1 | head -5" stall-check
own_case "here-document with an apostrophe and canary text" $'python3 '"$UREP"$' redact <<\'EOF\'\nI didn\'t expect CANARY_HEREDOC_h1\nEOF' usage-report
own_case "own file only a redirect target" "cat x > $UREP" ""
own_case "non-own script in a pipe, own name only as its argument" "printf x | sh /CANARY_other.sh $STALL" ""
own_case "non-own script in a pipe" "printf x | python3 /CANARY_elsewhere/usage-report.py redact" ""
own_case "unbalanced quote on the first line" "echo 'x && sh $STALL" ""
own_case "own script only on a later line" $'echo hi\nsh '"$STALL" ""
own_case "unbalanced quote" "sh \"$STALL" ""
reset_log; fire "$(tp PreToolUse Bash "$(jq -nc --arg c $'python3 '"$UREP"$' redact <<\'EOF\'\nI didn\'t expect CANARY_HEREDOC_h1 /CANARY_PATH_h2\nEOF' '{command:$c}')")"
one_line '.kind=="call" and .name=="usage-report"' && ! grep -q CANARY "$LOG" && pass "AC50 here-document body is never parsed or written (canary absent)" || fail "heredoc canary: $(cat "$LOG" 2>/dev/null)"
reset_log; fire "$(tp PreToolUse Bash '{"command":7}')"; fire "$(tp PreToolUse Bash '{}')"; fire "$(tp PostToolUse Bash '"x"')"
[ ! -e "$LOG" ] && pass "AC13 Bash with no or odd command: nothing recorded" || fail "odd command: $(cat "$LOG")"
# the plugin root decides: the same file under another plugin root is not the plugin's own script
reset_log; mkdir -p "$work/otherplugin/skills/workflow"; cp "$STALL" "$work/otherplugin/skills/workflow/"
fire "$(tp PreToolUse Bash "$(jq -nc --arg c "sh $work/otherplugin/skills/workflow/stall-check.sh" '{command:$c}')")"
[ ! -e "$LOG" ] && pass "AC50 same file name under another directory: not counted" || fail "other root: $(cat "$LOG")"
# a symlink into the plugin directory counts (macOS temp dirs are symlinks)
ln -s "$PR" "$work/plugin-link"; own_case "path through a symlink to the plugin dir" "sh $work/plugin-link/skills/workflow/stall-check.sh" stall-check
# a blocked command is a guard line only, the script inside it never runs
reset_log; fire "$(tp PreToolUse Bash "$(jq -nc --arg c "git rebase main && sh $STALL" '{command:$c}')")"
[ "$(jq -r .kind "$LOG" | tr '\n' ' ')" = "guard " ] && pass "AC53 a guard-blocked command gives the guard line and no script call line" || fail "guard + script: $(cat "$LOG" 2>/dev/null)"
# Monitor (probe 2026-11-19): PreToolUse and PermissionRequest carry {command, description, timeout_ms}; PostToolUse fires at launch with
# tool_response {taskId, persistent, timeoutMs}; PostToolUseFailure is the same shape as for other tools
MC="$(jq -nc --arg c "sh $STALL --transcript /CANARY_PATH_m1/t.jsonl --check 60 CANARY_ARG_m2" '{command:$c,description:"CANARY_DESC_m3",timeout_ms:1800000}')"
MR='{"tool_response":{"taskId":"CANARY_TASK_m4","persistent":false,"timeoutMs":1800000}}'
mcode=$(call_code sid-one Monitor "$MC")
reset_log; fire "$(tp PreToolUse Monitor "$MC")"
if one_line ".kind==\"call\" and .target==\"script\" and .name==\"stall-check\" and .call==\"$mcode\"" && [ "$(jq -c keys "$LOG")" = '["call","kind","name","session","target","time"]' ] && ! grep -q CANARY "$LOG"; then pass "AC2 PreToolUse Monitor of an own script: the same call line as Bash, no via"; else fail "AC2 monitor call: $(cat "$LOG" 2>/dev/null)"; fi
reset_log; fire "$(tp PermissionRequest Monitor "$MC" "$EXTRA")"
if one_line ".kind==\"ask\" and .target==\"script\" and .name==\"stall-check\" and .call==\"$mcode\"" && [ "$(jq -c keys "$LOG")" = '["call","kind","name","off","session","target","time","version"]' ] && ! grep -q CANARY "$LOG"; then pass "AC2 PermissionRequest Monitor: the same ask line as Bash, no via"; else fail "AC2 monitor ask: $(cat "$LOG" 2>/dev/null)"; fi
reset_log; fire "$(tp PermissionDenied Monitor "$MC" "$EXTRA")"
if one_line ".kind==\"script\" and .result==\"denied\" and .name==\"stall-check\" and .call==\"$mcode\"" && [ "$(jq -c keys "$LOG")" = '["call","kind","name","off","result","session","time","version"]' ] && ! grep -q CANARY "$LOG"; then pass "AC2 PermissionDenied Monitor: the same denied line as Bash, no via"; else fail "AC2 monitor denied: $(cat "$LOG" 2>/dev/null)"; fi
for case in "PostToolUse|$MR|ok" 'PostToolUseFailure|{"error":"CANARY_ERR_m5","is_interrupt":false}|failed' 'PostToolUseFailure|{"error":"CANARY_ERR_m5","is_interrupt":true}|aborted'; do
  IFS='|' read -r ev extra want <<<"$case"
  reset_log; fire "$(tp "$ev" Monitor "$MC" "$extra")"
  if one_line ".kind==\"script\" and .name==\"stall-check\" and .result==\"$want\" and .via==\"monitor\" and .call==\"$mcode\"" && [ "$(jq -c keys "$LOG")" = '["call","kind","name","off","result","session","time","version","via"]' ] && ! grep -q CANARY "$LOG"; then
    pass "AC3 Monitor $ev [$want]: one script line with via monitor, no command, task ID or error text"
  else fail "AC3 Monitor $ev [$want]: $(cat "$LOG" 2>/dev/null)"; fi
done
reset_log; fire "$(tp PostToolUse Bash "$SC" '{"tool_response":{"stdout":"x"}}')"
one_line '.kind=="script" and (has("via")|not)' && pass "AC3 a Bash-run script line carries no via field" || fail "AC3 bash via: $(cat "$LOG" 2>/dev/null)"
reset_log
for ev in PreToolUse PermissionRequest PermissionDenied PostToolUse PostToolUseFailure; do
  fire "$(tp "$ev" Monitor '{"command":"tail -f /CANARY_log_m6","description":"d","timeout_ms":1000}')"
  fire "$(tp "$ev" Monitor "$(jq -nc --arg c "sh /CANARY_elsewhere/skills/workflow/stall-check.sh" '{command:$c}')")"
  fire "$(tp "$ev" Monitor '{"command":7}')"; fire "$(tp "$ev" Monitor '{}')"
done
[ ! -e "$LOG" ] && pass "AC2 Monitor of any other command, outside the plugin or with no command: nothing recorded" || fail "AC2 monitor non-own: $(cat "$LOG")"
res=$(reset_log; for ev in PreToolUse PermissionRequest PermissionDenied PostToolUse PostToolUseFailure; do fire "$(tp "$ev" Monitor "$MC")"; done; validate_log "$LOG") && pass "Monitor lines pass the allowed-key validator ($res)" || fail "Monitor validator: $res"
# switch off: none of the new lines
reset_log; set_proj 'ordo usage_log: off\n'
for ev in PreToolUse PermissionRequest PermissionDenied PostToolUse PostToolUseFailure; do fire "$(tp "$ev" Skill "$SK")"; fire "$(tp "$ev" Bash "$SC")"; fire "$(tp "$ev" Monitor "$MC")"; fire "$(tp "$ev" Agent "$AG")"; done
quiet && [ ! -e "$HOME/.config" ] && pass "AC1/AC4 every new event obeys the usage_log switch" || fail "new events with usage_log off"
set_proj 'ordo usage_log: on\nordo qa_check: off\n'
# plain Bash early exit: time 50 runs
s=$(python3 -c 'import time;print(time.time())')
for _ in $(seq 50); do fire "$(tp PreToolUse Bash '{"command":"ls"}')"; done
e=$(python3 -c 'import time;print(time.time())')
ms=$(python3 -c "print(round(($e - $s) * 1000 / 50))")
quiet && [ ! -e "$LOG" ] && [ "$ms" -lt 400 ] && pass "plain Bash payload: no line, silent, $ms ms per run (50 runs, includes fire overhead)" || fail "plain bash timing/silence ($ms ms)"
res=$(reset_log; for ev in PreToolUse PermissionRequest PermissionDenied PostToolUse PostToolUseFailure; do fire "$(tp "$ev" Bash "$SC")"; fire "$(tp "$ev" Skill "$SK")"; done; validate_log "$LOG") && pass "call, ask, denied and script lines pass the allowed-key validator ($res)" || fail "call-family validator: $res"

# ---- T1c: guard family line (AC11) and the 90-day prune (AC16)
bash_payload() { jq -nc --arg c "$1" --arg cwd "$proj" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c},cwd:$cwd,session_id:"sid-one"}'; }
iso_ago() { python3 -c 'import sys,time;print(time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime(time.time()-float(sys.argv[1])*86400)))' "$1"; }
reset_log; clear_switches; set_proj 'ordo usage_log: on\n'
for pair in 'git rebase main CANARY_BRANCH_g1:rebase' 'git pull --rebase origin CANARY_BRANCH_g1:pull-rebase' 'git push --force origin CANARY_BRANCH_g1:force-push' 'rm -rf ~ CANARY_BRANCH_g1:rm-recursive' "bash -c 'git rebase CANARY_BRANCH_g1':rebase"; do
  reset_log; cmd=${pair%:*}; fam=${pair##*:}
  fire "$(bash_payload "$cmd")"
  if quiet && [ "$(nlines)" = 1 ] && [ "$(jq -c '[.kind,.family,.session]|tojson' "$LOG")" = "$(jq -nc --arg s "$(sha12 sid-one)" --arg f "$fam" '["guard",$f,$s]|tojson')" ] && [ "$(jq -c 'keys' "$LOG")" = '["family","kind","session","time"]' ] && ! grep -q CANARY "$LOG"; then
    pass "AC11 [$fam] one guard line: time, kind, family, session code; the command is not written"
  else fail "AC11 [$fam]: $(cat "$LOG" 2>/dev/null)"; fi
done
reset_log; fire "$(bash_payload 'git status && ls -la CANARY_ALLOWED_g2')"; fire "$(bash_payload 'git push origin main')"; fire "$(bash_payload 'rm -rf ./build')"
[ ! -e "$LOG" ] && pass "AC11 allowed commands: no line" || fail "AC11 allowed command logged: $(cat "$LOG")"
reset_log; set_proj 'ordo usage_log: on\nordo guard_hook: off\n'; fire "$(bash_payload 'git rebase main')"
quiet && [ ! -e "$LOG" ] && pass "guard off in the project: nothing is blocked, no block line" || fail "guard off project"
set_proj 'ordo usage_log: on\n'; set_global 'ordo guard_hook: off\n'; fire "$(bash_payload 'git rebase main')"
quiet && [ ! -e "$LOG" ] && pass "guard off globally: no block line" || fail "guard off global"
set_global 'ordo guard_hook: off\n'; set_proj 'ordo usage_log: on\nordo guard_hook: on\n'; fire "$(bash_payload 'git rebase main')"
[ "$(nlines)" = 1 ] && pass "project guard on beats global guard off: block line" || fail "guard on over off"
clear_switches
reset_log; fire "$(bash_payload 'git rebase main')"; set_proj 'ordo usage_log: off\n'; fire "$(bash_payload 'git rebase main')"
[ ! -e "$LOG" ] && pass "AC1/AC4 guard line obeys the usage_log switch" || fail "guard line with usage_log off"
set_proj 'ordo usage_log: on\n'
# guard_bash.py itself stays write-free: no open-for-write, no file-writing calls in its source
if grep -nE "open\([^)]*['\"][wax+]|os\.(write|makedirs|mkdir|rename|replace|remove|unlink|fchmod|chmod)|O_WRONLY|O_RDWR|O_CREAT|\.write\(" "$root/plugins/ordo/hooks/guard_bash.py" >"$work/gw"; then fail "AC23 guard_bash.py writes: $(head -3 "$work/gw" | tr '\n' ' ')"; else pass "AC23 guard_bash.py source holds no file-write call"; fi

# prune: only lines older than 90 days go; corrupt and future lines and order stay
write_log() { mkdir -p "$LOGDIR"; chmod 700 "$LOGDIR"; cat > "$LOG"; chmod 600 "$LOG"; }
reset_log; clear_switches; set_proj 'ordo usage_log: on\n'
o100=$(iso_ago 100); o95=$(iso_ago 95); o91=$(iso_ago 91); r89=$(iso_ago 89); r10=$(iso_ago 10)
write_log <<EOT
{"time":"$o100","kind":"start","session":"aaaaaaaaaaaa"}
not json at all
{"time":"$o95","kind":"end","session":"aaaaaaaaaaaa"}
{"time":"$o91","kind":"start","session":"bbbbbbbbbbbb"}
{"time":"$r89","kind":"end","session":"bbbbbbbbbbbb"}
{"time":"2099-01-01T00:00:00Z","kind":"start","session":"cccccccccccc"}
{"time":"garbage","kind":"start"}
{"time":5,"kind":"start"}
{"kind":"start"}
{"time":"$r10","kind":"end","session":"cccccccccccc"}
EOT
expected=$(sed -n '2p;5,10p' "$LOG")
fire "$(skill_payload ordo:tdd)"
got=$(head -n 7 "$LOG")
if quiet && [ "$(nlines)" = 8 ] && [ "$got" = "$expected" ] && [ "$(tail -n1 "$LOG" | jq -r .name)" = tdd ]; then
  pass "AC16 lines over 90 days removed; corrupt, future, undated and newer lines unchanged and in order; new line last"
else fail "AC16 prune: want [$expected] got [$got] lines=$(nlines)"; fi
[ "$(mode_of "$LOG")" = 600 ] && [ "$(mode_of "$LOGDIR")" = 700 ] && [ "$(ls -A "$LOGDIR")" = usage.jsonl ] && pass "after a prune: file 600, dir 700, no temp file left" || fail "after prune: $(ls -A "$LOGDIR") $(mode_of "$LOG")"
# no old line: no rewrite (same inode), line appended
ino1=$(python3 -c 'import os,sys;print(os.stat(sys.argv[1]).st_ino)' "$LOG")
fire "$(skill_payload ordo:tdd)"
ino2=$(python3 -c 'import os,sys;print(os.stat(sys.argv[1]).st_ino)' "$LOG")
[ "$ino1" = "$ino2" ] && [ "$(nlines)" = 9 ] && pass "no line over 90 days: file is not rewritten, line appended" || fail "rewrite without need (ino $ino1 -> $ino2, lines=$(nlines))"
# switch off: old lines stay (no write, so no prune)
reset_log; write_log <<EOT
{"time":"$o100","kind":"start","session":"aaaaaaaaaaaa"}
EOT
set_proj 'ordo usage_log: off\n'; fire "$(skill_payload ordo:tdd)"
[ "$(nlines)" = 1 ] && grep -q "$o100" "$LOG" && pass "usage_log off with a 100-day-old line: nothing written, nothing pruned" || fail "prune while off"
set_proj 'ordo usage_log: on\n'
# a file whose last line has no newline: the new line is not glued to it
reset_log; mkdir -p "$LOGDIR"; printf '{"half":' > "$LOG"
fire "$(skill_payload ordo:tdd)"
[ "$(head -n1 "$LOG")" = '{"half":' ] && [ "$(tail -n1 "$LOG" | jq -r .name)" = tdd ] && pass "half-written last line is left alone and the new line stands on its own line" || fail "glued line: $(cat "$LOG")"
# one 5 MB line without newline: appended quickly
reset_log; mkdir -p "$LOGDIR"; head -c 5000000 /dev/zero | tr '\0' x > "$LOG"
s=$(date +%s); fire "$(skill_payload ordo:tdd)"; e=$(date +%s)
[ "$(tail -n1 "$LOG" | jq -r .name)" = tdd ] && [ $((e - s)) -le 3 ] && quiet && pass "5 MB single line: appended in $((e - s)) s" || fail "5 MB line"
# prune of a big file (old line first) finishes in a few seconds and keeps the rest
reset_log; mkdir -p "$LOGDIR"; chmod 700 "$LOGDIR"
python3 -c '
import sys
sys.stdout.write("{\"time\":\"%s\",\"kind\":\"start\",\"session\":\"aaaaaaaaaaaa\"}\n" % sys.argv[1])
sys.stdout.write("{\"time\":\"2099-01-01T00:00:00Z\",\"kind\":\"start\",\"session\":\"aaaaaaaaaaaa\"}\n" * 400000)' "$o100" > "$LOG"
chmod 600 "$LOG"
s=$(date +%s); fire "$(skill_payload ordo:tdd)"; e=$(date +%s)
quiet && [ "$(nlines)" = 400001 ] && [ $((e - s)) -le 5 ] && pass "prune of a 20 MB file: $((e - s)) s, 400000 lines kept" || fail "big prune ($((e - s)) s, lines=$(nlines))"
# first line longer than the 64 KB head, then an old line: the prune check still sees the old line
reset_log; mkdir -p "$LOGDIR"; chmod 700 "$LOGDIR"
{ head -c 70000 /dev/zero | tr '\0' x; printf '\n{"time":"%s","kind":"start","session":"aaaaaaaaaaaa"}\n{"time":"%s","kind":"end","session":"bbbbbbbbbbbb"}\n' "$o100" "$r10"; } > "$LOG"; chmod 600 "$LOG"
fire "$(skill_payload ordo:tdd)"
if quiet && ! grep -q aaaaaaaaaaaa "$LOG" && grep -q bbbbbbbbbbbb "$LOG" && [ "$(head -c 70000 "$LOG" | tr -d x | wc -c | tr -d ' ')" = 0 ] && [ "$(nlines)" = 3 ]; then
  pass "70 KB junk first line then an old line: old line pruned, junk and newer lines kept"
else fail "long first line prune: lines=$(nlines) $(grep -c aaaaaaaaaaaa "$LOG")"; fi
# lock budget: a held lock makes the hook give up within about 2 s, writing nothing
reset_log; mkdir -p "$LOGDIR"; chmod 700 "$LOGDIR"
python3 -c '
import fcntl, os, sys, time
fd = os.open(sys.argv[1], os.O_RDONLY | os.O_DIRECTORY)
fcntl.flock(fd, fcntl.LOCK_EX)
print("held", flush=True)
time.sleep(6)' "$LOGDIR" > "$work/held" &
holder=$!
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do [ -s "$work/held" ] && break; sleep 0.1; done
s=$(python3 -c 'import time;print(time.time())'); fire "$(skill_payload ordo:tdd)"; e=$(python3 -c 'import time;print(time.time())')
kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null
el=$(python3 -c "print(round($e - $s, 1))")
if quiet && [ ! -e "$LOG" ] && python3 -c "import sys;sys.exit(0 if 1.5 <= $el <= 3.0 else 1)"; then pass "lock held by another process: gives up after $el s (budget about 2 s), no line"; else fail "lock budget ($el s, rc=$rc)"; fi
# stale temp files of a killed prune are removed under the lock; fresh ones and other files stay
reset_log; mkdir -p "$LOGDIR"; chmod 700 "$LOGDIR"
printf 'x' > "$LOGDIR/.usage-stale1.tmp"; printf 'x' > "$LOGDIR/.usage-fresh1.tmp"; printf 'x' > "$LOGDIR/.usage-other.txt"; printf 'x' > "$LOGDIR/notes.tmp"
touch -t 202001010000 "$LOGDIR/.usage-stale1.tmp" "$LOGDIR/.usage-other.txt" "$LOGDIR/notes.tmp"
fire "$(skill_payload ordo:tdd)"
if quiet && [ ! -e "$LOGDIR/.usage-stale1.tmp" ] && [ -e "$LOGDIR/.usage-fresh1.tmp" ] && [ -e "$LOGDIR/.usage-other.txt" ] && [ -e "$LOGDIR/notes.tmp" ] && [ "$(nlines)" = 1 ]; then
  pass "stale .usage-*.tmp (over a minute) removed; fresh temp, other files and the log stay"
else fail "stale temp cleanup: $(ls -A "$LOGDIR" | tr '\n' ' ')"; fi
# concurrency: writers contend with a prune and none loses its line
reset_log; mkdir -p "$LOGDIR"; chmod 700 "$LOGDIR"
python3 -c '
import sys
sys.stdout.write("{\"time\":\"%s\",\"kind\":\"start\",\"session\":\"aaaaaaaaaaaa\"}\n" % sys.argv[1])
sys.stdout.write("{\"time\":\"2099-01-01T00:00:00Z\",\"kind\":\"start\",\"session\":\"aaaaaaaaaaaa\"}\n" * 400000)' "$o100" > "$LOG"
chmod 600 "$LOG"
pids=()
for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
  ( cd "$proj" && printf '%s' "$(skill_payload ordo:tdd "writer-$i")" | python3 "$hook" >/dev/null 2>&1 ) &
  pids+=($!)
  [ "$i" = 1 ] && sleep 0.05
done
for pid in "${pids[@]}"; do wait "$pid"; done
missing=0
for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
  c=$(grep -c "\"session\":\"$(sha12 "writer-$i")\"" "$LOG" || true); [ "$c" = 1 ] || missing=$((missing + 1))
done
[ "$missing" = 0 ] && [ "$(grep -c 'aaaaaaaaaaaa' "$LOG")" = 400000 ] && pass "12 concurrent writers during a prune: every line present once, old line gone, 400000 kept" || fail "concurrency: $missing writers missing, aaaa lines $(grep -c aaaaaaaaaaaa "$LOG")"

# ---- AC21: banned names in the hook source
if grep -nE '\b(socket|http|urllib|requests|subprocess|importlib)\b|os\.system|os\.popen|__import__' "$hook" >"$work/ban"; then fail "AC21 banned name in hook source: $(head -3 "$work/ban" | tr '\n' ' ')"; else pass "AC21 hook source names no network module, subprocess, os.system, os.popen, __import__, importlib"; fi

# ---- AC22: fail open on every path: exit 0, empty stdout, empty stderr
reset_log; clear_switches; set_proj 'ordo usage_log: on\n'
for bad in '' 'not json {' '[]' '"str"' '{"hook_event_name":5}' '{"hook_event_name":"PreToolUse","tool_name":"Skill","tool_input":"x"}' '{"hook_event_name":"SessionStart","source":[1]}' '{"hook_event_name":"PostToolUse","tool_name":"Agent","tool_input":[],"tool_response":5}' '{"hook_event_name":"PostToolUseFailure","tool_name":"Bash","tool_input":5,"error":[1],"is_interrupt":{}}' '{"hook_event_name":"PermissionRequest","tool_name":7,"tool_input":"x"}' '{"hook_event_name":"PermissionDenied","tool_name":"Skill","tool_input":{"skill":[]},"reason":5}' '{"hook_event_name":"SubagentStart","agent_id":{},"agent_type":5}' '{"hook_event_name":"SubagentStop","agent_type":"ordo:qa","last_assistant_message":[1]}' '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":["sh"]}}'; do
  fire "$bad"
  quiet && pass "AC22 bad stdin [$bad]: silent exit 0" || fail "AC22 bad stdin [$bad] (rc=$rc out=[$out] err=[$err])"
done
big=$(python3 -c 'print("{\"hook_event_name\":\"SessionStart\",\"source\":\"startup\",\"x\":\"" + "a"*9000000 + "\"}")')
fire "$big"; quiet && pass "AC22 9 MB stdin: silent exit 0" || fail "AC22 huge stdin"
reset_log
out=$(cd "$proj" && printf '%s' "$(skill_payload ordo:tdd)" | env -u HOME python3 "$hook" 2>"$work/err") && rc=0 || rc=$?; err=$(cat "$work/err")
quiet && pass "AC22 HOME unset: silent exit 0" || fail "AC22 HOME unset"
for h in "" "relative/home"; do
  mkdir -p "$work/cwdrel/.claude"; printf 'ordo usage_log: on\n' > "$work/cwdrel/.claude/CLAUDE.md"; clear_switches
  out=$(cd "$work/cwdrel" && printf '%s' "$(skill_payload ordo:tdd)" | HOME="$h" python3 "$hook" 2>"$work/err") && rc=0 || rc=$?; err=$(cat "$work/err")
  if quiet && [ -z "$(find "$work/cwdrel" -name '*.jsonl' -o -name '.config' | head -1)" ]; then pass "AC22 HOME [$h]: nothing written, silent exit 0"; else fail "AC22 HOME [$h] (rc=$rc)"; fi
done
set_proj 'ordo usage_log: on\n'
# unwritable dir
reset_log; mkdir -p "$LOGDIR"; chmod 500 "$LOGDIR"
fire "$(skill_payload ordo:tdd)"; quiet && [ ! -e "$LOG" ] && pass "AC22 unwritable directory: silent exit 0" || fail "AC22 unwritable dir"
chmod 700 "$LOGDIR"
# symlinked log
reset_log; mkdir -p "$LOGDIR"; printf 'keep\n' > "$work/target.txt"; ln -s "$work/target.txt" "$LOG"
fire "$(skill_payload ordo:tdd)"; quiet && [ "$(cat "$work/target.txt")" = keep ] && pass "AC22 symlinked log: not followed, silent exit 0" || fail "AC22 symlinked log"
# log is a directory, a FIFO
reset_log; mkdir -p "$LOG"; fire "$(skill_payload ordo:tdd)"; quiet && pass "AC22 log path is a directory: silent exit 0" || fail "AC22 log dir"
reset_log; mkdir -p "$LOGDIR"; mkfifo "$LOG"; fire "$(skill_payload ordo:tdd)"; quiet && pass "AC22 log path is a FIFO: silent exit 0, no hang" || fail "AC22 fifo"
# symlinked log directory
reset_log; mkdir -p "$HOME/.config" "$work/elsewhere"; ln -s "$work/elsewhere" "$LOGDIR"
fire "$(skill_payload ordo:tdd)"; quiet && [ -z "$(ls -A "$work/elsewhere")" ] && pass "AC22 symlinked log directory: not followed" || fail "AC22 symlinked dir"
# corrupt file: binary garbage, hook still appends
reset_log; mkdir -p "$LOGDIR"; head -c 3000 /dev/urandom > "$LOG"; printf '\n{"half":' >> "$LOG"
before=$(nlines)
fire "$(skill_payload ordo:tdd)"
quiet && [ "$(tail -n1 "$LOG" | jq -r .name 2>/dev/null)" = tdd ] || [ "$(tail -c 200 "$LOG" | grep -c '"name":"tdd"')" = 1 ]
quiet && pass "AC22 corrupt log: still appends, silent exit 0" || fail "AC22 corrupt log"
# huge file: finishes quickly
reset_log; mkdir -p "$LOGDIR"; python3 -c '
import sys
line = "{\"time\":\"%s\",\"kind\":\"start\",\"session\":\"aaaaaaaaaaaa\"}\n"
sys.stdout.write((line % "2099-01-01T00:00:00Z") * 400000)' > "$LOG"
s=$(date +%s); fire "$(skill_payload ordo:tdd)"; e=$(date +%s)
quiet && [ $((e - s)) -le 3 ] && [ "$(nlines)" = 400001 ] && pass "AC22 20 MB log: appended in $((e - s)) s" || fail "AC22 huge log ($((e - s)) s, lines=$(nlines))"

# ---- file and directory modes
reset_log; (umask 000; fire "$(skill_payload ordo:tdd)")
[ "$(mode_of "$LOGDIR")" = 700 ] && [ "$(mode_of "$LOG")" = 600 ] && pass "dir created 700, file created 600 even under umask 000" || fail "modes dir=$(mode_of "$LOGDIR") file=$(mode_of "$LOG")"
chmod 666 "$LOG"; fire "$(skill_payload ordo:tdd)"
[ "$(mode_of "$LOG")" = 600 ] && pass "wide-mode file is tightened to 600" || fail "wide mode stays $(mode_of "$LOG")"

# ---- AC19: plain text, one JSON object per line
reset_log; fire "$(skill_payload ordo:tdd)"; fire "$(start_payload startup)"
if [ "$(jq -c . "$LOG" | wc -l | tr -d ' ')" = 2 ] && ! LC_ALL=C grep -q '[^[:print:]]' "$LOG"; then pass "AC19 plain text, one JSON object per line"; else fail "AC19"; fi

# ---- no .pyc next to the hook (importing guard_bash and goal_context must not write)
d="$work/nowrite"; mkdir -p "$d/hooks"
cp "$hook" "$d/hooks/usage_log.py"; cp "$root/plugins/ordo/hooks/guard_bash.py" "$root/plugins/ordo/hooks/goal_context.py" "$d/hooks/"
reset_log; before=$(cd "$d" && find . | sort)
out=$(cd "$proj" && printf '%s' "$(skill_payload ordo:tdd)" | env -u PYTHONDONTWRITEBYTECODE python3 "$d/hooks/usage_log.py" 2>/dev/null) || true
after=$(cd "$d" && find . | sort)
[ -f "$LOG" ] && [ "$before" = "$after" ] && pass "hook writes no .pyc next to itself (and does log)" || fail "pycache or no log: $(diff <(echo "$before") <(echo "$after") | tr '\n' ' ')"

# ---- hooks.json pins
hj="$root/plugins/ordo/hooks/hooks.json"
ss=$(jq -c '.hooks.SessionStart[1]' "$hj")
[ "$ss" = '{"matcher":"startup|clear","hooks":[{"type":"command","command":"python3 \"${CLAUDE_PLUGIN_ROOT}/hooks/usage_log.py\"","timeout":5}]}' ] && pass "hooks.json: SessionStart usage_log entry (startup|clear)" || fail "SessionStart[1]: $ss"
se=$(jq -c '.hooks.SessionEnd' "$hj")
[ "$se" = '[{"hooks":[{"type":"command","command":"python3 \"${CLAUDE_PLUGIN_ROOT}/hooks/usage_log.py\"","timeout":5}]}]' ] && pass "hooks.json: SessionEnd usage_log entry" || fail "SessionEnd: $se"
UE='{"type":"command","command":"python3 \"${CLAUDE_PLUGIN_ROOT}/hooks/usage_log.py\"","timeout":5}'
pt=$(jq -c '.hooks.PreToolUse[1]' "$hj")
[ "$pt" = '{"matcher":"Skill|Agent|Bash|Monitor","hooks":['"$UE"']}' ] && pass "hooks.json: PreToolUse usage_log entry (Skill|Agent|Bash|Monitor), after the guard's Bash entry" || fail "PreToolUse[1]: $pt"
pg=$(jq -c '.hooks.PreToolUse[0]' "$hj")
[ "$pg" = '{"matcher":"Bash","hooks":[{"type":"command","command":"python3 \"${CLAUDE_PLUGIN_ROOT}/hooks/guard_bash.py\"","timeout":10}]}' ] && [ "$(jq '.hooks.PreToolUse|length' "$hj")" = 2 ] && pass "hooks.json: the guard's PreToolUse entry is first and unchanged" || fail "PreToolUse[0]: $pg"
for ev in PostToolUse PostToolUseFailure; do
  pa=$(jq -c ".hooks.$ev" "$hj")
  [ "$pa" = '[{"matcher":"Agent|Skill|Bash|Monitor","hooks":['"$UE"']}]' ] && pass "hooks.json: $ev Agent|Skill|Bash|Monitor usage_log entry" || fail "$ev: $pa"
done
for ev in PermissionRequest PermissionDenied; do
  pa=$(jq -c ".hooks.$ev" "$hj")
  [ "$pa" = '[{"matcher":"Skill|Agent|Bash|Monitor","hooks":['"$UE"']}]' ] && pass "hooks.json: $ev Skill|Agent|Bash|Monitor usage_log entry" || fail "$ev: $pa"
done
for ev in SubagentStart SubagentStop; do
  pa=$(jq -c ".hooks.$ev" "$hj")
  [ "$pa" = '[{"hooks":['"$UE"']}]' ] && pass "hooks.json: $ev usage_log entry (no matcher, filtered in code)" || fail "$ev: $pa"
done
gm=$(jq -r '.hooks.SessionStart[0].matcher' "$hj")
[ "$gm" = 'startup|resume|compact' ] && pass "goal_context SessionStart matcher unchanged" || fail "goal matcher: $gm"

echo
if [ "$fails" -eq 0 ]; then echo "all passed"; else echo "$fails failed"; exit 1; fi
