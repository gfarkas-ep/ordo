---
timeout_seconds: 600
name: po-unmet-ambiguous
description: One criterion both unmet and ambiguous gives REJECTED, the criterion labelled unmet and named under escalations
tags: [po]
runs: 3
max_turns: 6
allowed_tools: [Agent]
---

Use the Agent tool to dispatch the ordo:po agent in acceptance mode. Give it the spec and the diff below, inline, exactly as written. No files exist; do not look for any. Then report the agent's reply verbatim.

--- SPEC ---
Spec for ticket "Survey invitation link":
1. Given a customer with a delivered order, when they request a survey on the order page, then the page shows the message "Survey link sent".
2. Given a customer with a delivered order, when they request a survey on the order page, then an email with the survey link is sent to the customer within a reasonable time.
3. Given an order that is not delivered, when a survey is requested on the order page, then the page shows the message "Survey not available yet" and no email is sent.

(Nothing in the spec defines "a reasonable time".)

--- CONTEXT ---
The helpers make_token(order_id), survey_url(token) and send_mail(to, body) already exist. The diff below is the complete change. The survey page is a public marketing-feedback form: it shows no personal data and changes no account data. Test run on this diff: 2 passed, 0 failed.

--- DIFF ---
```diff
+++ b/survey.py
+def request_survey(order):
+    if order.status != "delivered":
+        return "Survey not available yet"
+    token = make_token(order.id)
+    return "Survey link sent"
+++ b/test_survey.py
+def test_delivered_order_shows_confirmation(delivered_order):
+    assert request_survey(delivered_order) == "Survey link sent"
+
+def test_undelivered_order_shows_not_available(shipped_order, mail_spy):
+    assert request_survey(shipped_order) == "Survey not available yet"
+    assert mail_spy.calls == []
```
