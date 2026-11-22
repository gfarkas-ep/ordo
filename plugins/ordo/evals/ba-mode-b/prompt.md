---
timeout_seconds: 600
name: ba-mode-b
description: Mode B revise carries unanswered questions forward with their numbers and cleans up provisional criteria
tags: [ba]
runs: 3
max_turns: 6
allowed_tools: [Agent]
---

Use the Agent tool to dispatch the ordo:ba agent in Mode B (revise) with the input below, inline, exactly as written. No files exist; do not look for any. Then report the agent's reply verbatim.

--- PREVIOUS SPEC ---
## Spec
### User story
As a shopper, I want a faster and nicer checkout, so that I finish orders more often.
### Acceptance criteria
- AC1: Given a shopper with items in the cart, when they open checkout, then the page shows the order total.
- AC2: Given a shopper on checkout, when the page loads, then it is ready within the agreed time (provisional, Q1).
- AC3: Given a shopper on checkout, when they pay, then the agreed payment methods are offered (provisional, Q2).
- AC4: Given a shopper on checkout, when they finish, then the agreed confirmation is shown (provisional, Q3).
### Edge cases
- Empty cart.
### Business rules
- none
### Out of scope
- Redesign of the product pages.
### Assumptions
- none
## Questions
1. What is the maximum page load time? — Recommended: 2 seconds
2. Which payment methods are offered? — Recommended: card and PayPal
3. Should the confirmation also be sent by email? — Recommended: yes
4. Should guests be able to check out without an account? — Recommended: yes
## Not verified
- No code or docs were read.

--- USER ANSWERS ---
Q1: 2 seconds is fine.
Q2: card only, no PayPal.
(The user has not answered Q3 or Q4 yet.)
