---
name: eval-plan-before-run
description: "AC24-AC26, AC28: the user asks to run a plugin's evals with 4 runs per case. The scaffold holds acme-plugin with three cases and a prior results JSON (0.20, 0.30 and 0.50 USD per run, so 4 runs cost 4.00 USD). ordo:eval-plan must show the plan before any run: case names, expected pass rate, a budget of $4.00 derived from the prior results, and a stop rule; no `plugin eval` command may be run before the user's yes. Run with --scaffold and --allow-tools Bash. The yes/no loop is not covered (single prompt)."
tags: [bash-skills]
# requires: claude plugin eval ... --scaffold --allow-tools Bash
runs: 3
max_turns: 8
allowed_tools: [Skill, Bash, Read, Glob, Grep]
---

Please run the evals of the plugin in ./acme-plugin with 4 runs per case.
