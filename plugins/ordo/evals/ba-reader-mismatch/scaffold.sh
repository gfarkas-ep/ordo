#!/bin/bash
# docs/archive-policy.md: 30 lines, the real rule sits on line 12 (180 days).
# docs/plotline-*.md: five generated filler docs (~48KB), the "additional large material".
set -e
mkdir -p docs
{
echo "# Archive policy"
for n in 1 2 3 4 5 6 7 8 9 10; do echo "Policy note $n. Archiving moves a project out of the active list and keeps its contents unchanged."; done
echo "Archived projects stay readable for 180 days after archiving, then they are deleted."
for n in 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29; do echo "Policy note $n. Owners may restore an archived project from the archive page before it is deleted."; done
} > docs/archive-policy.md
topics=(boards members notifications billing exports)
for t in "${topics[@]}"; do
  f=docs/plotline-$t.md
  echo "# Plotline $t" > "$f"
  for n in $(seq 1 45); do
    echo "Section $n. The $t service keeps item $n in its own table and shows it in the web app on the $t page. Staff may rename item $n at any time; the change appears for all members after the next refresh." >> "$f"
    echo "" >> "$f"
  done
done
