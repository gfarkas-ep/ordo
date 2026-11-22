---
name: eval-plan-after-run
description: "AC27: the eval run is finished; the user asks to compare it with the plan at ./plan.md (budget $4.00 and 1440 s, 100% expected, stop rule: abort above $6.00). The results JSON ./results/run.json deviates: refund-policy passed 2 of 4 runs, cost is $5.60 (over plan by $1.60), duration 1680 s. ordo:eval-plan must compare actual with plan and name the failing case and the cost overrun, and write nothing. Run with --scaffold and --allow-tools Bash."
tags: [bash-skills]
# requires: claude plugin eval ... --scaffold --allow-tools Bash
runs: 3
max_turns: 8
allowed_tools: [Skill, Bash, Read, Glob, Grep]
---

The eval run for acme-plugin has finished. The plan is in ./plan.md and the results JSON is ./results/run.json. Compare how the run went against the plan.
