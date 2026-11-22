---
timeout_seconds: 900
name: po-reads-in-full
description: PO reads a 7023-line design doc in full (paging past the copy rule COPY-4 at line 3516) and rejects work whose expired-link message differs from it. Run with --scaffold.
tags: [po]
# requires: claude plugin eval ... --scaffold
runs: 3
max_turns: 6
allowed_tools: [Agent]
---

Use the Agent tool to dispatch the ordo:po agent in acceptance mode with the brief below, inline, exactly as written. Do not read any file yourself. Then report the agent's reply verbatim.

--- BRIEF ---
Acceptance of finished work against the spec.
SPEC: docs/specs/2026-10-20-link-expiry.md (in the current working directory). The spec relies on docs/design/HARBOR_DESIGN.md (same directory tree).
FINISHED WORK: src/links.py (in the current working directory).
