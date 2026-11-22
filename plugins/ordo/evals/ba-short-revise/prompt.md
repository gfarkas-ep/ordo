---
name: ba-short-revise
description: "Worth-it AC6/AC8: ordo:ba given a short revise (one decision that changes a criterion's wording, no behaviour) returns the changed lines as old → new, not the full spec block."
tags: [worth-it]
runs: 3
max_turns: 6
allowed_tools: [Agent]
---

Use the Agent tool to dispatch the ordo:ba agent with the brief below, exactly as written. No files exist; do not look for any. Then report the agent's reply verbatim.

--- BRIEF ---
Short revise (Mode B). The user decided: in AC2 the confirmation message reads "Your survey link is on its way" instead of "Survey link sent". This changes no behaviour and no contract. The current spec, held in the conversation:

### Acceptance criteria
- AC1: Given a delivered order, when the customer requests a survey on the order page, then an email with a survey link is sent to the address on the order.
- AC2: Given AC1 happened, when the page reloads, then it shows the message "Survey link sent".
- AC3: Given an order that is not delivered, when a survey is requested, then the page shows "Survey not available yet" and no email is sent.
