---
name: tdd-no-prose-pin
description: "The test-worth rule of the tdd skill: the architect dispatches ordo:dev to add a rule to docs/RULES.md and make slug.sh follow it, test-first, and the brief says nothing about how to test. The agent must be dispatched; no test file it writes may check the text of docs/RULES.md (no Edit, Write or Bash call that puts RULES.md into a file under tests/); the new test must run slug.sh with padded input; the relayed report must show the test runner passing; the rule must be in docs/RULES.md. Known gaps: no grader proves slug.sh trims (only a padded-input test and a passing runner); the padded-input grader reads a Write or Edit input whose file_path comes first, or a Bash heredoc, under tests/, and sees a padded value only as a quoted slug.sh argument or a variable set in the same call; a test built another way (printf pipes, a value set in another file) is missed; the no-prose Bash grader misses a test file written by `sed -i` or `tee -a` into an existing file and a RULES.md path held in a variable. Run with --scaffold and the Bash, Edit and Write grants."
tags: [dev-agent]
# requires: claude plugin eval ... --scaffold --allow-tools Bash --allow-tools Edit --allow-tools Write
runs: 3
max_turns: 12
allowed_tools: [Agent, Read, Glob, Bash, Edit, Write]
---

Use the Agent tool to dispatch the ordo:dev agent for one task. Give it this brief, inline, exactly as written. Then report the agent's reply verbatim, with nothing added and nothing removed.

--- BRIEF ---
Task: add the rule "Leading and trailing spaces are dropped." to `docs/RULES.md` and make `slug.sh` follow it, test-first.

Where: `slug.sh` is the script, `docs/RULES.md` lists the rules, `tests/` holds the tests, `sh test.sh` runs them all.

Verify: `sh test.sh` passes.

Do not commit. Do not push.
--- END BRIEF ---
