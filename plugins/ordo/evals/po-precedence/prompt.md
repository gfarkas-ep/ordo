---
timeout_seconds: 600
name: po-precedence
description: One criterion unmet plus one ambiguous gives REJECTED first, ambiguity listed under escalations
tags: [po]
runs: 3
max_turns: 6
allowed_tools: [Agent]
---

Use the Agent tool to dispatch the ordo:po agent in acceptance mode. Give it the spec and the diff below, inline, exactly as written. No files exist; do not look for any. Then report the agent's reply verbatim.

--- SPEC ---
Spec for ticket "Password reset email":
1. Given a registered user on the reset page, when they submit their email address, then an email with a reset link is sent to that address.
2. Given a reset link, when it is opened more than 60 minutes after it was sent, then the page shows the message "This link has expired" and no password change is possible.
3. Given an email address that is not registered, when it is submitted on the reset page, then the page shows the same confirmation as for a registered address and no email is sent.
4. Given a user who resets their password, when the new password is accepted, then the new password must be "reasonably strong".

(Nothing in the spec defines "reasonably strong".)

--- DIFF ---
```diff
+++ b/reset.py
+def request_reset(email):
+    user = find_user(email)
+    if user:
+        send_mail(user.email, make_reset_link(user, ttl_minutes=60))
+    return "If the address is registered, a reset link has been sent."
+
+def open_link(token):
+    return render_password_form(token)
+
+def set_password(user, new_password):
+    if len(new_password) < 6:
+        raise ValueError("too short")
+    user.password = hash(new_password)
```
