---
timeout_seconds: 600
name: po-accepted
description: Diff meets all criteria, verdict ACCEPTED
tags: [po]
runs: 3
max_turns: 6
allowed_tools: [Agent]
---

Use the Agent tool to dispatch the ordo:po agent in acceptance mode. Give it the spec and the diff below, inline, exactly as written. No files exist; do not look for any. Then report the agent's reply verbatim.

--- SPEC ---
Spec for ticket "Survey invitation link":
1. Given a customer with a delivered order, when they request a survey on the order page, then an email with a survey link is sent to the customer's email address on the order.
2. Given a survey link, when it is opened more than 60 minutes after it was sent, then the page shows the message "This survey link has expired".
3. Given an order that is not delivered, when a survey is requested on the order page, then the page shows the message "Survey not available yet" and no email is sent.

--- CONTEXT ---
The helpers make_token(order_id, sent_at) (returns a token with a .sent_at field), survey_url(token), send_mail(to, body) and render_survey(token) already exist and behave as their names say. The order page and the survey page display the string each handler returns. The diff below is the complete change. The survey page is a public marketing-feedback form: it shows no personal data and changes no account data. Test run on this diff: 5 passed, 0 failed.

--- DIFF ---
```diff
+++ b/survey.py
+def request_survey(order, now):
+    if order.status != "delivered":
+        return "Survey not available yet"
+    token = make_token(order.id, sent_at=now)
+    send_mail(order.customer_email, survey_url(token))
+    return "Survey link sent"
+
+def token_age_minutes(token, now):
+    return (now - token.sent_at).total_seconds() / 60
+
+def open_link(token, now):
+    if token_age_minutes(token, now) > 60:
+        return "This survey link has expired"
+    return render_survey(token)
+++ b/test_survey.py
+def test_request_sends_link_to_order_email(delivered_order, now, mail_spy):
+    assert request_survey(delivered_order, now) == "Survey link sent"
+    assert mail_spy.calls[0].to == delivered_order.customer_email
+    assert "survey" in mail_spy.calls[0].body
+
+def test_request_for_undelivered_order_sends_nothing(shipped_order, now, mail_spy):
+    assert request_survey(shipped_order, now) == "Survey not available yet"
+    assert mail_spy.calls == []
+
+def test_link_open_at_exactly_60_minutes_shows_survey(now):
+    token = make_token(1, sent_at=now - timedelta(minutes=60))
+    assert open_link(token, now) == render_survey(token)
+
+def test_link_open_at_61_minutes_is_expired(now):
+    token = make_token(1, sent_at=now - timedelta(minutes=61))
+    assert open_link(token, now) == "This survey link has expired"
+
+def test_token_age_is_in_minutes(now):
+    token = make_token(1, sent_at=now - timedelta(hours=2))
+    assert token_age_minutes(token, now) == 120
```
