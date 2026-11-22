---
name: eval-plan
description: Plan a paid or long eval or benchmark run before it starts, and compare the result with the plan after it. Use before starting any eval, benchmark or test-suite run that costs money or takes long (for example `claude plugin eval`), and after it finishes to compare actual against plan.
---

# Eval plan

Works for any project and any paid or long eval or benchmark run. Worked example throughout: `claude plugin eval`. Paid runs spend the user's money and time, so the user sees the numbers first and says yes.

## Before the run

1. **Write the plan.** Four parts, all required:
   - **Cases**: every case the run will execute, by name, and the runs per case.
   - **Expected pass rate**: a number (for example 11/12), with one line of why.
   - **Budget**: cost and wall time.
     - When a last results JSON exists, derive both from it and show the figures: the average `costUsd` per case over its prior runs, times the planned runs, summed, and the same for duration. For `claude plugin eval` read `.cases[].arms.with[].costUsd` and `.durationSeconds`. Example: `(0.12 + 0.45) x 3 runs = $1.71`.
     - When none exists, write "guess" next to the figure and say why (no prior run, different cases, different model).
   - **Stop rule**: when to abort (spend or time passed, a failure count reached) and what counts as a failure (`passed` false, an error, a timeout).
   - **With `ordo eval_budget: off`** (switch rule: `ordo:workflow`): write no cost figure and no spend clause in the stop rule. The Budget part is then the wall-time estimate from the last results JSON `durationSeconds` or marked "guess". Cases with runs per case, Expected pass rate, the "time passed" clause, the failure count and what counts as a failure stay. The plan is still saved, shown in full, and waits for the explicit yes (steps 2 to 4).
2. **Save it** as plain markdown in the session scratchpad. Name it `eval-plan-<run>.md`; the words report, findings and summary stay out of the name. Write nothing to the repo and commit nothing.
3. **Show it to the user** in full and ask for a yes.
4. **Wait.** Start no eval command until the user says an explicit yes in their own message. Silence, an earlier request to run, and "sounds fine" about something else are not a yes. Edit the plan on any change request and show it again.

**Done when** the plan is shown with all four parts, and the run has not started.

## After the run

1. Read the plan and the results JSON. A run aborted by the stop rule still gets this step, on the partial results.
2. Compare actual with plan, one line each: cases run (against the list), pass rate, cost, duration, stop rule triggered or not.
   - With `ordo eval_budget: off`, the comparison covers cases run, pass rate, duration and stop rule triggered or not, and states no cost deviation.
3. State each deviation with both figures and the difference (`cost $2.40 against $1.71, +$0.69`). Name the case behind a failed run. Where the stop rule triggered, say which clause.
4. Write nothing to the repo. Show the comparison in the reply. Leave fixing the failures and updating the plan to the user.

**Done when** every plan line has an actual next to it and every deviation is stated with its figures.
