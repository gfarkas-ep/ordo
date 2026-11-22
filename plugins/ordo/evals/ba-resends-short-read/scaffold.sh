#!/bin/bash
# docs/archive-policy.md: 40 lines. Line 12 holds the retention rule (180 days), line 39 the
# extension rule; the prior reader reply in the brief stops at line 30, so line 39 is uncovered.
set -e
mkdir -p docs
{
echo "# Archive policy"
for n in 1 2 3 4 5 6 7 8 9 10; do echo "Policy note $n. Archiving moves a project out of the active list and keeps its contents unchanged."; done
echo "Archived projects stay readable for 180 days after archiving, then they are deleted."
for n in 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37; do echo "Policy note $n. Owners may restore an archived project from the archive page before it is deleted."; done
echo "An owner may extend the readable period of one archived project once, by 30 days, before the 180 days end."
echo "End of the archive policy."
} > docs/archive-policy.md
