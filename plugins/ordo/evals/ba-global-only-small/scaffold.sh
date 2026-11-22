#!/bin/bash
# Global CLAUDE.md with a very low reader threshold (level 3 of AC9), written to the run's
# isolated HOME, plus two small neutral Plotline docs (~2.6k tokens in all: above 1000, far below
# the 200000 default). No project CLAUDE.md. Small set: nothing in it invites a settings check.
# Safety: never touches the real home; refuses if HOME is the user's or the file exists.
set -e
set -o noclobber
real_home=$(dscl . -read "/Users/$(id -un)" NFSHomeDirectory 2>/dev/null | awk '{print $2}')
[ -n "$real_home" ] || real_home=$(getent passwd "$(id -un)" | cut -d: -f6)
[ -n "$real_home" ] || { echo "refusing: cannot resolve the real home" >&2; exit 1; }
case $HOME in /*) ;; *) echo "refusing: HOME is not an absolute path: $HOME" >&2; exit 1 ;; esac
# -ef compares device and inode, so firmlink/symlink aliases of the real home are caught too
p=$HOME
while [ -n "$p" ] && [ "$p" != / ]; do
  if [ -e "$p" ] && [ "$p" -ef "$real_home" ]; then echo "refusing: HOME is the real home: $HOME" >&2; exit 1; fi
  p=${p%/*}
done
if [ -e "$HOME/.claude/CLAUDE.md" ]; then echo "refusing: $HOME/.claude/CLAUDE.md exists" >&2; exit 1; fi
mkdir -p "$HOME/.claude"
cat > "$HOME/.claude/CLAUDE.md" <<'MD'
# Global notes

ordo reader_threshold_tokens: 1000
ordo reader_cap_tokens: 1000
ordo reader_cap_files: 1
MD
mkdir -p docs
topics=(boards billing)
for t in "${topics[@]}"; do
  f=docs/plotline-$t.md
  echo "# Plotline $t" > "$f"
  for n in $(seq 1 24); do
    echo "Section $n. The $t service keeps item $n in its own table and shows it in the web app on the $t page. Staff may rename item $n at any time; the change appears for all members after the next refresh." >> "$f"
    echo "" >> "$f"
  done
  if [ "$t" = billing ]; then
    echo "Projects with an open billing dispute are never archived automatically, whatever archive period the owner has chosen; the project stays active until the dispute is closed." >> "$f"
  fi
  echo "End of $t notes." >> "$f"
done
