---
timeout_seconds: 600
name: po-escalate-scope-cut
description: Diff meets the clear criteria but proposes cutting a spec item, verdict ESCALATE (not REJECTED) with the cut named under Escalations
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
4. Given a user who has just reset their password, when the reset succeeds, then a notification email is sent to the user's address.

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
+    if token_age_minutes(token) > 60:
+        return render("This link has expired")
+    return render_password_form(token)
```

Note from the developer: criterion 4 (notification email after a successful reset) is not implemented in this diff. I propose we cut it from the scope of this ticket and handle it in a later release.
