---
timeout_seconds: 600
name: ba-no-questions
description: Fully specified request yields Questions section with none
tags: [ba]
runs: 3
max_turns: 6
allowed_tools: [Agent]
---

Use the Agent tool to dispatch the ordo:ba agent with the request below, inline, exactly as written. No files exist; do not look for any. Then report the agent's reply verbatim.

--- REQUEST ---
Add a "Download invoice as PDF" button to the order detail page.
Inputs: the order id from the page URL; the logged-in user must own the order. A logged-in user who does not own the order, or opens a non-existent order id, gets the existing "Not found" 404 page, with no button and no PDF. Logged-out users are redirected to login by the existing behaviour. Every order has a billing address.
Output: a PDF file named invoice-<order id>.pdf containing order lines, totals, VAT and the billing address, generated from the existing invoice template.
Edge cases: orders with status "cancelled" show no button, and a direct request for a cancelled order's PDF gets the same "Not found" 404 page; if PDF generation fails the page shows the message "Invoice unavailable, try again later" and logs the error; orders with more than 100 lines are truncated to the first 100 lines, and the PDF shows the note "Showing first 100 of <n> lines" under the table, where <n> is the real line count (the existing invoice template already has a free-text slot under the table for such notes); totals and VAT always cover the full order, not only the lines shown.
Out of scope: emailing invoices, bulk download, changing the invoice template, any other page.
Performance: PDF generated within 5 seconds for orders up to 100 lines; no limit is set for larger orders. Existing tests must keep passing.
