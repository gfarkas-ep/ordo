#!/bin/bash
# Project CLAUDE.md with a low reader threshold (level 2 of AC9) and five neutral Plotline
# docs (~10KB each, ~12k tokens in all: above 5000, far below the 200000 default).
# The deciding rule (billing dispute) sits in the fourth file, near its end.
set -e
cat > CLAUDE.md <<'MD'
# Plotline

Notes for this project.

ordo reader_threshold_tokens: 5000
ordo reader_cap_tokens: 5000
ordo reader_cap_files: 2
MD
mkdir -p docs
topics=(boards members notifications billing exports)
for i in 0 1 2 3 4; do
  t=${topics[$i]}
  f=docs/plotline-$t.md
  echo "# Plotline $t" > "$f"
  for n in $(seq 1 45); do
    echo "Section $n. The $t service keeps item $n in its own table and shows it in the web app on the $t page. Staff may rename item $n at any time; the change appears for all members after the next refresh." >> "$f"
    echo "" >> "$f"
  done
  if [ "$t" = billing ]; then
    echo "Projects with an open billing dispute are never archived automatically, whatever archive period the owner has chosen; the project stays active until the dispute is closed." >> "$f"
  fi
  echo "End of $t notes." >> "$f"
done
