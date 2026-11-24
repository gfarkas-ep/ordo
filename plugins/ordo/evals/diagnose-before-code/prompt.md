---
name: diagnose-before-code
description: "Base ordo:diagnose behaviour: the user reports a bug in a scaffolded node project (`checkout([{price: 100, qty: 2}], 10)` returns 190 where a 10% discount should give 180). The ordo:diagnose skill must be loaded before any source file is read (tool order), and the reply must name one repro command and give 3 to 5 ranked, falsifiable hypotheses. The skill loading is a setup check, the rest is behaviour. The source is read with the Read tool only: a shell read of it (cat, grep, sed and the like) fails the case, because tool_order cannot guard optional tools; the Grep tool is not allowed at all. Run with --scaffold and --allow-tools Bash."
tags: [bash-skills]
# requires: claude plugin eval ... --scaffold --allow-tools Bash
runs: 3
max_turns: 12
allowed_tools: [Skill, Read, Glob, Bash]
---

Bug report from a user of this project: `checkout([{ price: 100, qty: 2 }], 10)` in `price.js` returns 190, and a 10% discount on 200 should give 180. Diagnose it.

Show me your ranked hypotheses before you test any of them; I will re-rank them. Do not change any file.
