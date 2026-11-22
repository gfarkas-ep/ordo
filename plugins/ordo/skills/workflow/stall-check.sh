#!/bin/sh
# Stall check for a background helper. Read-only: lists processes and reads file sizes; writes no file, makes no network call, kills nothing.
# Usage: stall-check.sh --transcript PATH --check SECONDS [--file PATH]... [--pattern TEXT] [--root PID] [--max-checks N]
#                       [--report SECONDS] [--next-report SECONDS] [--pid PID]
#   --root       the session process (positive integer); default: the first ancestor that is not a shell (the Monitor tool starts the script inside a shell wrapper).
#   --pattern    plain text, matched literally against every process command line (no regex, no quoting of special characters).
#   --max-checks stop after N checks (the first one is the baseline); default: loop until the caller ends the script.
#   --report     print a report line every SECONDS (never more often than a check); timing counts from script start; without it, no report lines.
#   --next-report the first report comes after this many seconds instead of --report (a re-arm keeps the old schedule).
#   --pid        exit 0, no output, when this process no longer exists (checked at every check).
#   TERM, INT and HUP end the script at once: no output, the sleep between checks is stopped too.
# Output, stdout only, one line per finding, nothing for the baseline check except the note line:
#   suspect: no growth, no child CPU; transcript=<bytes>; idle: <pid> <etime> <command> | ...
#   suspect: transcript flat 3 checks; transcript=<bytes>; idle: ...     (every 3rd flat check in a row, whatever the CPU)
#   suspect: no process matches '<pattern>'; transcript=<bytes>
#   report: transcript=<bytes> (+<delta> since last report); child CPU +<s>s; files: <path>=<bytes> ... |none; pattern: found|none (only with --pattern); idle: ...|none
# note: cannot read transcript <path>, size counted as 0     (first check only, also on stderr; only stdout wakes the session)
# An idle entry shows `eval '<inner>'` for a command that holds eval '...', and any entry over 120 characters is cut to 117 plus ...
# Idle child = a descendant of the root (not this script or its own children) whose cumulative CPU time did not grow since the last check.

transcript=
every=
files=
pattern=
root=
max=
report=
nextrep=
wpid=
while [ $# -gt 0 ]; do
  case $1 in
    --transcript) transcript=$2 ;;
    --check) every=$2 ;;
    --file) files="$files
$2" ;;
    --pattern) pattern=$2 ;;
    --root) root=$2 ;;
    --max-checks) max=$2 ;;
    --report) report=$2 ;;
    --next-report) nextrep=$2 ;;
    --pid) wpid=$2 ;;
    *) echo "stall-check: unknown argument $1" >&2; exit 2 ;;
  esac
  [ $# -ge 2 ] || { echo "stall-check: $1 needs a value" >&2; exit 2; }
  shift 2
done
case $every in ''|*[!0-9]*|0) echo "stall-check: --check needs a positive integer (seconds)" >&2; exit 2 ;; esac
case $max in *[!0-9]*|0) echo "stall-check: --max-checks needs a positive integer" >&2; exit 2 ;; esac
case $root in *[!0-9]*|0) echo "stall-check: --root needs a positive integer" >&2; exit 2 ;; esac
case $report in *[!0-9]*|0) echo "stall-check: --report needs a positive integer (seconds)" >&2; exit 2 ;; esac
case $nextrep in *[!0-9]*|0) echo "stall-check: --next-report needs a positive integer (seconds)" >&2; exit 2 ;; esac
case $wpid in *[!0-9]*|0) echo "stall-check: --pid needs a positive integer" >&2; exit 2 ;; esac
[ -z "$nextrep" ] || [ -n "$report" ] || { echo "stall-check: --next-report needs --report" >&2; exit 2; }
export STALL_PATTERN=$pattern
[ -n "$transcript" ] || { echo "stall-check: --transcript is required" >&2; exit 2; }

# say TEXT: one stdout line, printed as is (echo would turn a literal \012 in a command line, as ps prints a newline there, into a real newline)
say() { printf '%s\n' "$1"; }

# size_of PATH: byte count, 0 when unreadable; wc -c follows symlinks
size_of() {
  s=$({ wc -c < "$1"; } 2>/dev/null) || s=0
  echo $((${s:-0} + 0))
}

# stdin: ps lines "pid ppid time etime command". Prints G <children that gained CPU>, S <pid:seconds ...>, I <idle list>, M <pattern matches>, or E <reason>
# Lines that are not a ps record (a command line with a newline in it) are skipped, so every finding stays one line.
# Excluded from the idle list and the pattern match: this script and its children, its ancestors below the root, and every
# other instance with its children: first word ends in /stall-check.sh, or first word is a shell and the second ends in /stall-check.sh;
# the ancestors of such an instance below the root are excluded too (the Monitor tool runs its command inside a wrapper shell).
# No --root: the root is the first ancestor whose command is not a shell (the Monitor tool wraps the script in a shell).
analyse() {
  awk -v root="$root" -v self="$$" -v start="$PPID" -v prev="$1" '
function secs(t,   d, a, n, s, k) {
  d = 0
  if (index(t, "-")) { split(t, a, "-"); d = a[1]; t = a[2] }
  n = split(t, a, ":")
  s = 0
  for (k = 1; k <= n; k++) s = s * 60 + a[k]
  return d * 86400 + s
}
function isshell(c,   w, b) {
  split(c, w, " "); b = w[1]
  sub(/^-/, "", b); sub(/.*\//, "", b)
  return (b == "sh" || b == "bash" || b == "zsh" || b == "dash")
}
function ours(c,   w) {
  split(c, w, " ")
  if (w[1] ~ /(^|\/)stall-check\.sh$/) return 1
  return (isshell(c) && w[2] ~ /(^|\/)stall-check\.sh$/)
}
function short(c,   i, r, j) {
  i = index(c, "eval \047")
  if (i) { r = substr(c, i + 6); j = index(r, "\047"); c = "eval \047" (j ? substr(r, 1, j) : r) }
  if (120 < length(c)) c = substr(c, 1, 117) "..."
  return c
}
BEGIN {
  pat = ENVIRON["STALL_PATTERN"]
  n = split(prev, pa, " ")
  for (i = 1; i <= n; i++) { split(pa[i], kv, ":"); pv[kv[1]] = kv[2] }
}
$1 !~ /^[0-9]+$/ || $2 !~ /^[0-9]+$/ || $3 !~ /^[0-9:.-]+$/ || $4 !~ /^[0-9:.-]+$/ { next }
{
  pid = $1; par[pid] = $2; cpu[pid] = secs($3); et[pid] = $4
  c = $5
  for (i = 6; i <= NF; i++) c = c " " $i
  cmd[pid] = c; order[++cnt] = pid
}
END {
  if (cnt == 0) { print "E no ps records"; exit }
  if (root == "") {
    r = start; g = 0
    while ((r in cmd) && isshell(cmd[r]) && g++ < 50) r = par[r]
    root = r
  }
  if (!(root in cmd)) { print "E root process " root " not found"; exit }
  p = par[self]; g = 0
  while ((p in cmd) && p != root && g++ < 50) { anc[p] = 1; p = par[p] }
  kid[root] = 1; me[self] = 1
  for (j = 1; j <= cnt; j++) {
    x = order[j]
    if (x == root || !ours(cmd[x])) continue
    me[x] = 1
    split("", chain); p = par[x]; g = 0
    while ((p in cmd) && p != root && g++ < 50) { chain[p] = 1; p = par[p] }
    if (p == root) for (q in chain) anc[q] = 1
  }
  do {
    moved = 0
    for (j = 1; j <= cnt; j++) {
      p = order[j]
      if (!(p in kid) && (par[p] in kid)) { kid[p] = 1; moved = 1 }
      if (!(p in me) && (par[p] in me)) { me[p] = 1; moved = 1 }
    }
  } while (moved)
  gained = 0; dsum = 0; state = ""; idle = ""; match_n = 0
  for (j = 1; j <= cnt; j++) {
    p = order[j]
    if ((p in me) || (p in anc)) continue
    if (pat != "" && index(cmd[p], pat)) match_n++
    if (!(p in kid) || p == root) continue
    old = (p in pv) ? pv[p] : 0
    state = state " " p ":" cpu[p]
    if (old < cpu[p]) { gained++; dsum += cpu[p] - old }
    else idle = idle (idle == "" ? "" : " | ") p " " et[p] " " short(cmd[p])
  }
  print "G " gained
  printf "D %.2f\n", dsum
  print "S" state
  print "I " idle
  print "M " match_n
}'
}

n=0
prev_t=
prev_f=
prev_state=
flat=0
rep_t=
cpu_list=
next_rep=${nextrep:-$report}
sp=
trap 'trap - TERM INT HUP; [ -z "$sp" ] || kill "$sp" 2>/dev/null; exit 0' TERM INT HUP
while :; do
  if [ -n "$wpid" ] && ! ps -p "$wpid" >/dev/null 2>&1; then exit 0; fi
  n=$((n + 1))
  elapsed=$(((n - 1) * every))
  t=$(size_of "$transcript")
  if [ "$n" = 1 ] && [ "$t" = 0 ] && ! ( : < "$transcript" ) 2>/dev/null; then
    echo "stall-check: cannot read transcript $transcript, size counted as 0" >&2
    say "note: cannot read transcript $transcript, size counted as 0"
  fi
  [ "$n" -gt 1 ] || rep_t=$t
  fsizes=
  fdesc=
  oldifs=$IFS
  IFS='
'
  for f in $files; do sz=$(size_of "$f"); fsizes="$fsizes $sz"; fdesc="$fdesc $f=$sz"; done
  IFS=$oldifs
  psout=$(ps -A -o pid=,ppid=,time=,etime=,command= 2>/dev/null)
  fail=
  if [ -z "$psout" ]; then
    fail="ps returned nothing"
  else
    res=$(printf '%s\n' "$psout" | analyse "$prev_state" 2>/dev/null)
    fail=$(printf '%s\n' "$res" | sed -n 's/^E //p' | head -1)
    case $res in *G\ *) ;; *) [ -n "$fail" ] || fail="process analysis gave no result" ;; esac
  fi
  if [ -n "$fail" ]; then
    say "suspect: check failed: $fail; transcript=$t"
  else
    gained=$(printf '%s\n' "$res" | sed -n 's/^G //p')
    state=$(printf '%s\n' "$res" | sed -n 's/^S *//p')
    idle=$(printf '%s\n' "$res" | sed -n 's/^I //p')
    matches=$(printf '%s\n' "$res" | sed -n 's/^M //p')
    dsum=$(printf '%s\n' "$res" | sed -n 's/^D //p')
    [ -n "$idle" ] || idle=none
    if [ "$n" -gt 1 ]; then
      if [ "$t" = "$prev_t" ]; then flat=$((flat + 1)); else flat=0; fi
      if [ "$flat" -ge 3 ]; then
        say "suspect: transcript flat 3 checks; transcript=$t; idle: $idle"
        flat=0
      elif [ "$t" -le "$prev_t" ] && [ "$fsizes" = "$prev_f" ] && [ "$gained" = 0 ]; then
        say "suspect: no growth, no child CPU; transcript=$t; idle: $idle"
      fi
      if [ -n "$pattern" ] && [ "$matches" = 0 ]; then
        say "suspect: no process matches '$pattern'; transcript=$t"
      fi
      cpu_list="$cpu_list $dsum"
      if [ -n "$report" ] && [ "$elapsed" -ge "$next_rep" ]; then
        while [ "$next_rep" -le "$elapsed" ]; do next_rep=$((next_rep + report)); done
        cpu=$(awk -v l="$cpu_list" 'BEGIN { n = split(l, a, " "); s = 0; for (i = 1; i <= n; i++) s += a[i]; printf "%.2f", s }')
        pat_note=
        if [ -n "$pattern" ]; then
          if [ "$matches" = 0 ]; then pat_note="; pattern: none"; else pat_note="; pattern: found"; fi
        fi
        say "report: transcript=$t ($(printf '%+d' $((t - rep_t))) since last report); child CPU +${cpu}s; files:${fdesc:- none}$pat_note; idle: $idle"
        rep_t=$t
        cpu_list=
      fi
    fi
    prev_state=$state
  fi

  prev_t=$t
  prev_f=$fsizes
  if [ -n "$max" ] && [ "$n" -ge "$max" ]; then break; fi
  sleep "$every" &
  sp=$!
  wait "$sp"
  sp=
done
