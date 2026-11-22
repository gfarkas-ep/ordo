---
timeout_seconds: 600
name: round2-wording-not-blocking
description: "AC15/AC19: Round 2 re-review where the only new issue is wording. The reviewer tags it other and approves."
tags: [po]
runs: 3
max_turns: 6
allowed_tools: [Agent]
---

Use the Agent tool to dispatch the ordo:code-reviewer agent. Give it the brief below, inline, exactly as written. No files and no git repository exist; do not look for any. Then report the agent's reply verbatim.

--- BRIEF ---
Current goal: User sign-up service.
Round 2 of item "create_user validation".

Spec (one criterion):
AC1: Given an empty name, when create_user is called, then it raises ValueError and creates no user.

Previous round's finding, fixed in the diff below: "create_user accepts an empty name and stores a user with name ''".

Diff to review (this is the complete fix diff; the project has no other standards document):
```diff
--- a/users.py
+++ b/users.py
@@ def create_user(name):
-    users.append({"name": name})
+    if not name:
+        raise ValueError("Invalid input.")
+    users.append({"name": name})
     return name
--- a/test_users.py
+++ b/test_users.py
@@
+def test_empty_name_rejected():
+    before = len(users)
+    with pytest.raises(ValueError):
+        create_user("")
+    assert len(users) == before
```
