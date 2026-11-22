#!/bin/bash
# Tests for plugins/ordo/hooks/guard_bash.py. Free: stdin payloads only, no network, no Claude run.
# Seam: hook stdin -> stdout + exit code. Set GUARD=<path> to test another script (used for the red run).
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
guard=${GUARD:-$root/plugins/ordo/hooks/guard_bash.py}
tmp_root=${TMPDIR:-/tmp}
tmp_root=${tmp_root%/}
work=$(mktemp -d "$tmp_root/guard-test.XXXXXX")
cleanup() {
  if [ -n "${work:-}" ] && [ -d "$work" ] && [ "${work#"$tmp_root"/}" != "$work" ]; then
    rm -r "$work"
  fi
}
trap cleanup EXIT

command -v jq >/dev/null || { echo "jq is required" >&2; exit 2; }
command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 2; }
[ -f "$guard" ] || { echo "guard script not found: $guard" >&2; exit 2; }

fakehome="$work/fakehome"   # stands in for the user's real home path
mkdir -p "$work/payloads"

fails=0
total=0
pass() { echo "ok   - $1"; }
fail() { echo "FAIL - $1"; fails=$((fails + 1)); }

# run_guard <stdin-text>: sets out, err, rc
run_guard() {
  out=$(cd "${rundir:-.}" && printf '%s' "$1" | HOME="$fakehome" python3 "$guard" 2>"$work/err") && rc=0 || rc=$?
  err=$(cat "$work/err")
}

# sample <deny|allow> <family|-> <command>: Bash payload; checks exit 0, verdict, reason on deny
sample() {
  local want=$1 family=$2 cmd=$3 payload verdict reason
  total=$((total + 1))
  payload=$(jq -n --arg c "$cmd" '{tool_name: "Bash", tool_input: {command: $c}}')
  printf '%s' "$payload" > "$work/payloads/$total.json"
  run_guard "$payload"
  if [ "$rc" -ne 0 ]; then fail "$want [$cmd]: exit $rc, want 0"; return; fi
  if [ "$want" = allow ]; then
    if [ -z "$out" ]; then pass "allow [$cmd]"; else fail "allow [$cmd]: unexpected stdout: $out"; fi
    return
  fi
  verdict=$(jq -r '.hookSpecificOutput.permissionDecision // empty' <<<"$out" 2>/dev/null) || verdict=
  reason=$(jq -r '.hookSpecificOutput.permissionDecisionReason // empty' <<<"$out" 2>/dev/null) || reason=
  if [ "$verdict" != deny ]; then fail "deny [$cmd]: not denied (stdout: ${out:-<empty>})"; return; fi
  if [ "$(jq -r '.hookSpecificOutput.hookEventName' <<<"$out")" != PreToolUse ]; then fail "deny [$cmd]: hookEventName is not PreToolUse"; return; fi
  case $reason in *"rule $family"*) ;; *) fail "deny [$cmd]: reason does not name rule $family: $reason"; return ;; esac
  case $reason in *'! '*) ;; *) fail "deny [$cmd]: reason lacks the '! <command>' escape: $reason"; return ;; esac
  pass "deny($family) [$cmd]"
}

# raw <label> <want: allow|failopen> <stdin-text> [closed-stdin]: fail-open and malformed payload paths
raw() {
  local label=$1 want=$2 input=$3
  total=$((total + 1))
  printf '%s' "$input" > "$work/payloads/$total.json"
  run_guard "$input"
  if [ "$rc" -eq 2 ]; then fail "$label: exit 2 (would block)"; return; fi
  if [ "$rc" -ne 0 ]; then fail "$label: exit $rc, want 0"; return; fi
  if [ -n "$out" ]; then fail "$label: stdout not empty: $out"; return; fi
  if [ "$want" = failopen ]; then
    case $err in *"failed open"*) ;; *) fail "$label: stderr lacks 'failed open': ${err:-<empty>}"; return ;; esac
  fi
  pass "$label"
}

# --- rebase (AC2) -----------------------------------------------------------
for c in 'git rebase main' 'git rebase -i HEAD~3' 'git rebase --continue' 'git rebase --abort'; do
  sample deny rebase "$c"
done
# --- pull --rebase (AC3) ----------------------------------------------------
for c in 'git pull --rebase' 'git pull -r' 'git pull --rebase=true origin main'; do
  sample deny pull-rebase "$c"
done
# --- force push (AC4 + edge cases) ------------------------------------------
for c in 'git push --force' 'git push -f' 'git push --force-with-lease' 'git push origin +main' 'git push origin +HEAD:main' \
  'git push -fu origin x' 'git push --force-with-lease=ref' 'git push --force-if-includes'; do
  sample deny force-push "$c"
done
# --- rm of root/home (AC5) --------------------------------------------------
for c in 'rm -rf /' 'rm -fr ~' 'rm -r $HOME' 'rm --recursive /' "rm -rf $fakehome" 'rm -rf ~/*' \
  'rm -rf /*' 'rm -rf ~/' 'rm -rf ${HOME}' 'rm -rf "$HOME/"' 'rm -rf $HOME/*' "rm -rf $fakehome/" "rm -rf $fakehome/*" \
  'rm -R ~/' 'rm -rf build ~' 'rm -rf -- /'; do
  sample deny rm-recursive "$c"
done
# --- allowed: AC5b ----------------------------------------------------------
for c in 'rm -rf ~/dev/old-project' 'rm -rf $HOME/x' 'rm -rf /tmp/x' 'rm -rf ./build' "rm -rf $fakehome/x"; do
  sample allow - "$c"
done
# --- allowed: AC6 + edge cases ----------------------------------------------
for c in 'git reset --hard' 'git branch -D x' 'git push origin main' 'git pull' 'git pull --ff-only' 'rm -rf ./build' \
  'rm file.txt' 'rm -rf /tmp/x' 'git commit -m "no rebase"' 'echo "git push --force"' 'git log --grep=rebase' \
  'grep rebase file' 'rm -r build/' 'rm /' 'rm ~' 'rm -f /' 'git push -u origin x' 'git pull --no-rebase' 'git pull -Xours' \
  'git pull --rebase=false' 'git pull --rebase=no origin main' 'git pull --rebase=FALSE' 'git pull --rebase=No' \
  'echo ";" git rebase' "echo '&&' git push -f" "printf '%s|' git rebase" 'echo "||" git rebase' \
  "echo 'git rebase'" 'git status' 'bash -c "echo hi"' 'bash -c "git status"'; do
  sample allow - "$c"
done
# --- compound (AC7) ---------------------------------------------------------
sample deny rebase 'ls && git rebase main'
sample deny force-push 'true; git push -f'
sample deny rebase 'cat x | git rebase x'
sample deny rm-recursive 'a || rm -rf ~'
sample deny rebase $'ls\ngit rebase main'
sample allow - 'ls && git status; echo done | cat'
# --- wrapped (AC8 + edge cases) ---------------------------------------------
sample deny rebase 'bash -c "git rebase main"'
sample deny rebase "sh -c 'git rebase main'"
sample deny rebase "zsh -c 'git rebase main'"
sample deny rebase 'sudo git rebase'
sample deny force-push 'env FOO=1 git push -f'
sample deny rebase 'git -C /repo rebase main'
sample deny rebase 'git -c k=v rebase main'
sample deny pull-rebase 'git -C /r -c k=v pull --rebase'
for v in true merges interactive i m anything; do sample deny pull-rebase "git pull --rebase=$v"; done
sample deny rebase 'ls ; git rebase main'
sample deny force-push 'a&&git push -f'
sample deny rebase 'echo ";" ; git rebase main'
sample deny rm-recursive 'sudo rm -rf /'
sample deny rebase 'git -C dir -c k=v rebase'
sample deny rebase 'sudo env X=1 git rebase main'
sample deny rebase 'sudo -u root git rebase main'
sample deny rebase 'FOO=1 git rebase main'
sample deny rebase '"git" "rebase" main'
sample deny rebase "bash -c \"sh -c 'git rebase main'\""
# 3 nested -c levels are parsed as argv
sample deny rebase "bash -c \"sh -c 'zsh -c \\\"git rebase main\\\"'\""
# deeper than 3 levels: the innermost string gets the raw regex scan (documented in guard_bash.py): still denied, benign still allowed
deep() { local c=$1 i; for i in 1 2 3 4 5 6; do c="bash -c '${c//\'/\'\\\'\'}'"; done; printf '%s' "$c"; }
sample deny rebase "$(deep 'git rebase main')"
sample allow - "$(deep 'git status')"
# --- shlex failure: raw regex scan (AC9) ------------------------------------
sample deny rebase 'echo "oops; git rebase main'
sample deny rebase 'echo "oops; git --no-pager -C /r -c k=v rebase main'
sample deny force-push 'echo "oops; git push --force origin x'
sample deny rm-recursive 'echo "oops; rm -rf ~'
sample allow - 'echo "unclosed quote'
sample allow - 'git commit -m "unclosed message'
sample allow - 'echo "x; git pull --rebase=false'
sample deny pull-rebase 'echo "x; git pull --rebase=true'
# --- shell keywords and wrappers are looked through ---------------------------------
sample deny pull-rebase 'for r in a b; do git -C $r pull --rebase; done'
sample deny rebase 'if true; then git rebase main; fi'
sample deny rebase '{ git rebase main; }'
sample deny rebase '! git rebase main'
sample deny force-push 'time git push -f'
sample deny force-push 'nohup git push -f'
sample deny rebase 'timeout 5 git rebase main'
sample deny rebase 'timeout -k 2 --signal=TERM 5 git rebase main'
sample deny rebase 'nice -n 5 git rebase main'
sample deny rebase 'while true; do git rebase main; done'
sample deny rebase 'echo `git rebase main`'
sample deny rebase 'echo $(git rebase main)'
sample allow - 'echo then'
sample allow - 'echo do git'
sample allow - 'time git status'
sample allow - 'timeout 5 ls'
sample allow - 'nice -n 5 make'
# --- comments and heredoc bodies are text, not commands -------------------------------
sample allow - $'cat > s.sh <<\'EOF\'\ngit pull --rebase\nEOF'
sample allow - $'cat > s.sh <<EOF\ngit push -f\nEOF'
sample allow - $'cat <<-EOF\n\tgit rebase main\n\tEOF'
sample allow - "echo hi # it's git rebase main"
sample allow - 'echo hi # git rebase main'
sample allow - 'echo a#b git rebase'
sample allow - $'cat > n.md <<\'EOF\'\nDon\'t run git rebase main here\nEOF'
sample allow - $'git commit -m "$(cat <<\'EOF\'\nAdd guard hook\n\nIt blocks git rebase and git push --force; don\'t bypass it.\nEOF\n)"'
sample allow - $'git commit -m $(cat <<\'EOF\'\nDon\'t run git rebase main here\nEOF\n)'
sample allow - $'cat <<EOF > a.txt && git status\nrm -rf ~\nEOF'
# a heredoc fed to a shell is executed, so its body is checked
sample deny rebase $'bash <<\'EOF\'\ngit rebase main\nEOF'
sample deny force-push $'sh <<EOF\nls\ngit push -f\nEOF'
sample allow - $'bash <<\'EOF\'\necho hi\nEOF'
sample deny rebase $'cat <<EOF | bash\ngit rebase main\nEOF'
sample deny force-push $'cat <<\'EOF\' | sudo /bin/sh\ngit push -f\nEOF'
sample deny rebase $'bash -c "$(cat <<EOF\ngit rebase main\nEOF\n)"'
sample allow - $'cat <<EOF | grep x\ngit rebase main\nEOF'
sample allow - $'cat <<EOF | bash\necho hi\nEOF'
# unterminated heredoc is not a heredoc: the text is still scanned
sample deny rebase $'cat <<EOF\ngit rebase main'
# --- raw scan must not backtrack exponentially --------------------------------------
total=$((total + 1))
slow=$(python3 -c 'print("echo \"x; git" + " -C" * 40 + " x")')
printf '%s' "$(jq -n --arg c "$slow" '{tool_name: "Bash", tool_input: {command: $c}}')" > "$work/slow.json"
t0=$(python3 -c 'import time; print(time.time())')
out=$(HOME="$fakehome" python3 "$guard" <"$work/slow.json" 2>/dev/null) && rc=0 || rc=$?
t1=$(python3 -c 'import time; print(time.time())')
ms=$(python3 -c "print(round(($t1 - $t0) * 1000))")
if [ "$rc" -eq 0 ] && [ -z "$out" ] && [ "$ms" -lt 500 ]; then pass "raw scan, pathological '-C' input: allowed in $ms ms"; else fail "raw scan, pathological input: rc=$rc out=${out:-<empty>} ${ms} ms (want < 500)"; fi

total=$((total + 1))
slow=$(python3 -c 'print("echo \"x; git" + " --a=b" * 60 + " x")')
printf '%s' "$(jq -n --arg c "$slow" '{tool_name: "Bash", tool_input: {command: $c}}')" > "$work/slow2.json"
t0=$(python3 -c 'import time; print(time.time())')
out=$(HOME="$fakehome" python3 "$guard" <"$work/slow2.json" 2>/dev/null) && rc=0 || rc=$?
t1=$(python3 -c 'import time; print(time.time())')
ms=$(python3 -c "print(round(($t1 - $t0) * 1000))")
if [ "$rc" -eq 0 ] && [ -z "$out" ] && [ "$ms" -lt 500 ]; then pass "raw scan, pathological '--a=b' input: allowed in $ms ms"; else fail "raw scan, pathological input: rc=$rc out=${out:-<empty>} ${ms} ms (want < 500)"; fi

# --- payload shapes (AC10, AC11) --------------------------------------------
raw "missing tool_input" allow '{"tool_name":"Bash"}'
raw "tool_input without command" allow '{"tool_name":"Bash","tool_input":{}}'
raw "non-string command" allow '{"tool_name":"Bash","tool_input":{"command":5}}'
raw "non-Bash tool with rebase command" allow '{"tool_name":"Read","tool_input":{"command":"git rebase main"}}'
raw "non-Bash tool, file_path only" allow '{"tool_name":"Read","tool_input":{"file_path":"/x"}}'
raw "invalid JSON" failopen '{not json'
raw "empty stdin" failopen ''
# internal exception: closed stdin makes sys.stdin None inside the script
total=$((total + 1))
out=$(HOME="$fakehome" python3 "$guard" 2>"$work/err" <&-) && rc=0 || rc=$?
err=$(cat "$work/err")
if [ "$rc" -eq 0 ] && [ -z "$out" ] && case $err in *"failed open"*) true ;; *) false ;; esac; then
  pass "internal exception (closed stdin): exit 0, empty stdout, failed open"
else
  fail "internal exception (closed stdin): rc=$rc out=${out:-<empty>} err=${err:-<empty>}"
fi
echo '{"tool_name":"Bash","tool_input":{"command":"git rebase main"}}' > "$work/payloads/last.json"

# --- guard switch: `ordo guard_hook:` lines in <cwd>/CLAUDE.md and $HOME/.claude/CLAUDE.md ---------------
# gcase <label> <want: allow|deny> <project> <global> [cwd: path|none|num|rel]
# <project>/<global>: "-" no file, "@dir" directory named CLAUDE.md, "@unreadable" mode 000, else the file text.
# Every payload carries a cwd (saved for the latency loop). An allow case gets a positive control:
# same payload, CLAUDE.md files moved away, must be denied.
gdir=0
gglobal="$fakehome/.claude/CLAUDE.md"
put_claude() { # <path> <spec>
  case $2 in
    -) ;;
    @dir) mkdir -p "$1" ;;
    @fifo) mkfifo "$1" ;;
    @zero) ln -s /dev/zero "$1" ;;
    @big) { printf 'ordo guard_hook: off\n'; head -c 1100000 /dev/zero | tr '\0' x; printf '\n'; } > "$1" ;;
    @unreadable) printf 'ordo guard_hook: off\n' > "$1"; chmod 000 "$1" ;;
    *) printf '%s' "$2" > "$1" ;;
  esac
}
# run_limited <stdin-text>: like run_guard, but a guard that runs over 3 s is killed: rc 124 (a hang fails the test, not the suite)
cat > "$work/limit.py" <<'PY'
import subprocess, sys
try:
    r = subprocess.run([sys.executable, sys.argv[1]], input=sys.stdin.buffer.read(), capture_output=True, timeout=3)
except subprocess.TimeoutExpired:
    sys.stderr.write("TIMEOUT"); sys.exit(124)
sys.stdout.buffer.write(r.stdout); sys.stderr.buffer.write(r.stderr); sys.exit(r.returncode)
PY
run_limited() {
  out=$(cd "${rundir:-.}" && printf '%s' "$1" | HOME="$fakehome" python3 "$work/limit.py" "$guard" 2>"$work/err") && rc=0 || rc=$?
  err=$(cat "$work/err")
}
gcheck() { # <label> <want> <payload-file>
  local label=$1 want=$2 verdict
  run_limited "$(cat "$3")"
  if [ "$rc" -ne 0 ]; then fail "$label: exit $rc, want 0"; return 1; fi
  if [ "$want" = allow ]; then
    if [ -n "$out" ] || [ -n "$err" ]; then fail "$label: want allow, got stdout [${out:-}] stderr [${err:-}]"; return 1; fi
    return 0
  fi
  verdict=$(jq -r '.hookSpecificOutput.permissionDecision // empty' <<<"$out" 2>/dev/null) || verdict=
  case $verdict:$out in deny:*"rule rebase"*) return 0 ;; esac
  fail "$label: want deny(rebase), got stdout [${out:-<empty>}] stderr [${err:-}]"; return 1
}
gcase() {
  local label=$1 want=$2 proj=$3 glob=$4 mode=${5:-path} dir cwdval
  gdir=$((gdir + 1)); total=$((total + 1))
  dir="$work/proj.$gdir"; mkdir -p "$dir" "$fakehome/.claude"
  put_claude "$dir/CLAUDE.md" "$proj"; put_claude "$gglobal" "$glob"
  rundir=
  case $mode in
    path) jq -n --arg d "$dir" '{tool_name: "Bash", tool_input: {command: "git rebase main"}, cwd: $d}' > "$work/payloads/g$gdir.json" ;;
    none) jq -n '{tool_name: "Bash", tool_input: {command: "git rebase main"}}' > "$work/payloads/g$gdir.json" ;;
    num) jq -n '{tool_name: "Bash", tool_input: {command: "git rebase main"}, cwd: 5}' > "$work/payloads/g$gdir.json" ;;
    rel) rundir=$work
         jq -n --arg d "proj.$gdir" '{tool_name: "Bash", tool_input: {command: "git rebase main"}, cwd: $d}' > "$work/payloads/g$gdir.json" ;;
  esac
  if gcheck "$label" "$want" "$work/payloads/g$gdir.json"; then
    if [ "$want" = allow ]; then
      mv "$dir/CLAUDE.md" "$dir/CLAUDE.md.off" 2>/dev/null || true
      mv "$gglobal" "$gglobal.off" 2>/dev/null || true
      if gcheck "$label (control, lines absent)" deny "$work/payloads/g$gdir.json"; then pass "$want [$label]"; fi
      mv "$dir/CLAUDE.md.off" "$dir/CLAUDE.md" 2>/dev/null || true
    else
      pass "$want [$label]"
    fi
  fi
  rundir=
  chmod -R u+rw "$dir" "$gglobal" 2>/dev/null || true
  rm -rf "$gglobal" "$gglobal.off"
}
OFF=$'ordo guard_hook: off\n'
ON=$'ordo guard_hook: on\n'
gcase "off at project" allow "$OFF" -
gcase "off at global" allow - "$OFF"
OLDP=ro; OLDP+=les  # the old plugin prefix, built in parts
gcase "old prefix guard_hook: off does not switch off" deny "$OLDP guard_hook: off"$'\n' -
gcase "no lines at either level" deny - -
gcase "project on beats global off" deny "$ON" "$OFF"
gcase "project on, global on" deny "$ON" "$ON"
gcase "project maybe, global off gives off" allow $'ordo guard_hook: maybe\n' "$OFF"
gcase "project OFF upper-case ignored" deny $'ordo guard_hook: OFF\n' -
gcase "no space after colon ignored" deny $'ordo guard_hook:off\n' -
gcase "unknown key ignored" deny $'ordo guard_hok: off\n' -
gcase "git_rules off leaves the guard on (AC8)" deny $'ordo git_rules: off\n' -
gcase "git_rules off, guard_hook on" deny $'ordo git_rules: off\nordo guard_hook: on\n' -
gcase "CRLF line" allow $'# notes\r\nordo guard_hook: off\r\n' -
gcase "trailing spaces and tab" allow $'ordo guard_hook: off  \t\n' -
gcase "leading spaces, plain line" allow $'  ordo guard_hook: off\n' -
gcase "no trailing newline" allow 'ordo guard_hook: off' -
gcase "bulleted line ignored" deny $'- ordo guard_hook: off\n' -
gcase "indented bullet ignored" deny $'  - ordo guard_hook: off\n' -
gcase "prose line ignored" deny $'Set ordo guard_hook: off to allow rebase.\n' -
gcase "duplicate lines, last (on) wins" deny $'ordo guard_hook: off\nordo guard_hook: on\n' -
gcase "duplicate lines, last (off) wins" allow $'ordo guard_hook: on\nordo guard_hook: off\n' -
gcase "invalid last line does not cancel a valid one" allow $'ordo guard_hook: off\nordo guard_hook: maybe\n' -
gcase "project file not UTF-8" deny $'ordo guard_hook: off\n\xff\xfe\n' -
gcase "global file not UTF-8" deny - $'ordo guard_hook: off\n\xff\xfe\n'
gcase "directory named CLAUDE.md at project" deny @dir -
gcase "directory named CLAUDE.md at global" deny - @dir
gcase "no cwd" deny - -  none
gcase "no cwd, global off gives off" allow - "$OFF" none
gcase "non-string cwd" deny "$OFF" - num
gcase "non-string cwd, global off gives off" allow "$ON" "$OFF" num
gcase "relative cwd" deny "$OFF" - rel
gcase "unreadable project file, global off gives off" allow @unreadable "$OFF"
gcase "unreadable project file, global silent" deny @unreadable -
gcase "unreadable global file" deny - @unreadable
gcase "FIFO named CLAUDE.md at project" deny @fifo -
gcase "FIFO named CLAUDE.md at global" deny - @fifo
gcase "symlink to /dev/zero at project" deny @zero -
gcase "symlink to /dev/zero at global" deny - @zero
gcase "FIFO at project, global off gives off" allow @fifo "$OFF"
gcase "symlink to /dev/zero at project, global off gives off" allow @zero "$OFF"
gcase "file over 1 MB is silent" deny @big -
gcase "UTF-8 BOM before the line" allow $'\xef\xbb\xbfordo guard_hook: off\n' -
gcase "not UTF-8 project, global off gives off" allow $'\xff\xfe\n' "$OFF"
gcase "directory named CLAUDE.md at project, global off gives off" allow @dir "$OFF"

# --- AC1: hooks.json shape, its command runs the guard, stdlib-only imports -----------
hooks_json="$root/plugins/ordo/hooks/hooks.json"
if [ -f "$hooks_json" ] && jq -e '
    (.hooks | has("PreToolUse") and has("SessionStart"))
    and (.hooks.PreToolUse | length) >= 1
    and .hooks.PreToolUse[0].matcher == "Bash"
    and (.hooks.PreToolUse[0].hooks | length) == 1
    and .hooks.PreToolUse[0].hooks[0].type == "command"
    and .hooks.PreToolUse[0].hooks[0].command == "python3 \"${CLAUDE_PLUGIN_ROOT}/hooks/guard_bash.py\""
    and .hooks.PreToolUse[0].hooks[0].timeout == 10' "$hooks_json" >/dev/null 2>&1; then
  pass "hooks.json: valid, hooks wrapper, first PreToolUse entry is the guard (matcher Bash, one hook), python3 \${CLAUDE_PLUGIN_ROOT} command, timeout 10"
  hook_cmd=$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$hooks_json")
  out=$(echo '{"tool_name":"Bash","tool_input":{"command":"git rebase main"}}' | CLAUDE_PLUGIN_ROOT="$root/plugins/ordo" bash -c "$hook_cmd" 2>/dev/null) || true
  if [ "$(jq -r '.hookSpecificOutput.permissionDecision' <<<"$out" 2>/dev/null)" = deny ]; then pass "hooks.json command (CLAUDE_PLUGIN_ROOT=plugins/ordo) denies git rebase main"; else fail "hooks.json command did not deny: ${out:-<empty>}"; fi
else
  fail "hooks.json missing or wrong shape: $hooks_json"
fi
n=$(jq '[.hooks.PreToolUse[].hooks[] | select(.command | contains("guard_bash.py"))] | length' "$hooks_json" 2>/dev/null)
[ "$n" = 1 ] && pass "hooks.json: exactly one PreToolUse hook command runs guard_bash.py" || fail "hooks.json: $n PreToolUse hook commands run guard_bash.py (want 1)"
if python3 -I - "$root/plugins/ordo/hooks/guard_bash.py" <<'PY'
import ast, sys
tree = ast.parse(open(sys.argv[1]).read())
mods = {a.name.split(".")[0] for n in ast.walk(tree) if isinstance(n, ast.Import) for a in n.names}
mods |= {n.module.split(".")[0] for n in ast.walk(tree) if isinstance(n, ast.ImportFrom) and n.module and n.level == 0}
bad = sorted(m for m in mods if m not in sys.stdlib_module_names)
print("non-stdlib imports:", bad) if bad else None
sys.exit(1 if bad or not mods else 0)
PY
then pass "guard_bash.py imports only the standard library"; else fail "guard_bash.py imports a non-stdlib module"; fi

# --- latency: all payloads again, average per call --------------------------
now() { python3 -c 'import time; print(time.time())'; }
start=$(now)
n=0
for f in "$work"/payloads/*.json; do
  HOME="$fakehome" python3 "$guard" <"$f" >/dev/null 2>&1 || true
  n=$((n + 1))
done
end=$(now)
avg_ms=$(python3 -c "print(round(($end - $start) / $n * 1000, 1))")
echo "latency: average $avg_ms ms per call over $n calls"
if python3 -c "import sys; sys.exit(0 if $avg_ms < 100 else 1)"; then pass "average latency < 100 ms"; else fail "average latency $avg_ms ms >= 100 ms"; fi

echo
echo "$total samples"
if [ "$fails" -eq 0 ]; then echo "all tests passed"; else echo "$fails test(s) failed"; exit 1; fi
