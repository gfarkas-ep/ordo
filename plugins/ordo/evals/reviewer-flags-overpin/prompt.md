---
name: reviewer-flags-overpin
description: "Worth-it AC9: ordo:code-reviewer, given a diff that adds a feature plus a test pinning an exact README sentence no code reads, reports the over-pin as a finding."
tags: [worth-it]
runs: 3
max_turns: 6
allowed_tools: [Agent]
---

Use the Agent tool to dispatch the ordo:code-reviewer agent, Round 1. Give it the spec and the diff below, inline, exactly as written. No files exist; do not look for any. Then report the agent's reply verbatim.

--- SPEC ---
Add a `--shout` flag to `greet`: when set, the greeting is returned in upper case. Existing behaviour without the flag is unchanged.

--- DIFF ---
```diff
--- a/acme.py
+++ b/acme.py
-def greet(name):
-    return "hi " + name
+def greet(name, shout=False):
+    text = "hi " + name
+    return text.upper() if shout else text
--- a/test_acme.py
+++ b/test_acme.py
 def test_greet():
     assert greet("a") == "hi a"
+
+def test_shout():
+    assert greet("a", shout=True) == "HI A"
+
+def test_readme_welcome():
+    assert "Welcome to acme, we hope you enjoy it!" in open("README.md").read()
```
Context: nothing in the code reads README.md; the welcome sentence is marketing copy the owner edits often. Test run: 3 passed.
