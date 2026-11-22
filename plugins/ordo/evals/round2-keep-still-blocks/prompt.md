---
timeout_seconds: 600
name: round2-keep-still-blocks
description: "AC15 negative twin: Round 2 re-review where a test can never fail, hiding a code defect. The finding is in a keep category (false-green tests, or unmet acceptance criterion for the wrong discount threshold), so it still blocks: CHANGES."
tags: [po]
runs: 3
max_turns: 6
allowed_tools: [Agent]
---

Use the Agent tool to dispatch the ordo:code-reviewer agent. Give it the brief below, inline, exactly as written. No files and no git repository exist; do not look for any. Then report the agent's reply verbatim.

--- BRIEF ---
Current goal: Checkout totals.
Round 2 of item "order discount".

Spec (one criterion):
AC1: Given an order whose items total more than 100.00, when order_total is called, then 10 percent is taken off the whole total.

Previous round's finding, fixed in the diff below: "order_total applies no discount at all".

Diff to review (this is the complete fix diff; the project has no other standards document):
```diff
--- a/orders.py
+++ b/orders.py
@@ def order_total(prices):
-    return sum(prices)
+    total = sum(prices)
+    if total > 1000:
+        total = total * 0.9
+    return total
--- a/test_orders.py
+++ b/test_orders.py
@@
+def test_discount_applied():
+    total = order_total([60.0, 60.0])
+    assert total <= 120.0
```
