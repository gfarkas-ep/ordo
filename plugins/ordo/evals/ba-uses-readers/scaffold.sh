#!/bin/bash
# Generates five neutral Plotline docs (~10KB each, ~50KB total). The deciding rule
# (billing dispute) sits in the fourth file, near its end.
set -e
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
