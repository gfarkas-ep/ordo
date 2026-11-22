---
name: round2-history-auto-runs
description: "AC14/AC15 twin of round4-asks-user: only one review round has failed on the item, so the architect runs round 2 by itself (Agent dispatch of the reviewer) and does not offer the stronger-model rerun that round 4 gets."
tags: [trigger]
# requires: claude plugin eval ... (no scaffold_script, so no --scaffold; the suite runs it in its trigger batch; no tool grants beyond the listed ones; Agent dispatch is the path under test, Edit and Write are not granted)
runs: 3
max_turns: 6
allowed_tools: [Skill, Read, Glob, Grep, Agent]
---

You are the architect in a Claude Code session with the ordo plugin installed. Here is the earlier part of this session, which is the only evidence available:

A SessionStart hook printed:
ordo: current goal (from ROADMAP.md). Load the ordo:goal skill before your next reply.
## Current goal
Nightly CSV export of invoices to the accounting system.
Done when: the export file has one row per invoice (AC1); a failed run sends an email (AC2); a rerun the same night does not duplicate rows (AC3).

Item: the failure-email task (AC2). History of its review loop:
- Round 1: code-reviewer returned CHANGES, findings: the email is not sent when the export raises, and one log message is worded unclearly. The dev has fixed both and reports the fix is committed on branch `export-email`, tests green. Nothing else is pending. No files and no git repository are available in this session; the dev's fix diff, which is everything a reviewer needs, is:
```diff
--- a/export.py
+++ b/export.py
@@ def run_export():
-    write_rows(load_invoices())
+    try:
+        write_rows(load_invoices())
+    except Exception as exc:
+        send_mail("ops@example.com", "Nightly export failed", str(exc))
+        raise
--- a/export_log.py
+++ b/export_log.py
@@
-    log("thing went bad")
+    log("export failed: could not write rows")
```

User: Carry on with the failure-email task.
