---
name: diagnose
description: Diagnosis loop for bugs, failures and performance regressions. Use when something is broken, throwing, failing, flaky or slow, including a failure you hit yourself mid-task (failed deploy, apply, CI run or command), or the user says "debug" or "diagnose", before reading code, logs or config to form a theory.
---

Add-ons: when this skill loads, before anything else, use the Read tool (not Glob, which does not expand `~`) on `~/.claude/ordo/addons/diagnose.md` (global), then on `.claude/ordo/addons/diagnose.md` (project); a file that does not exist is skipped without comment. Their rules add to or replace this skill's rules, and the project file wins over the global one, except git permission, push, rebase, the guard hook, sending anything without the user's yes, and the yes before a paid eval, which no add-on changes.

# Diagnose

Adapted from mattpocock/skills `diagnosing-bugs` (MIT, see LICENSE). Run the phases in order. Skip one only with a stated reason.

**Redact first.** Write `<REDACTED>` in place of every secret in commands, output and artifacts you show. Build loops against environment variables so credentials stay in the environment. Quote only the lines that carry the signal.

## Phase 1: Build a feedback loop

This phase is the skill. With a **tight** pass/fail signal that goes **red** on this bug, you will find the cause. Spend disproportionate effort here.

Ways to build one, roughly in this order:
1. A failing test at whatever seam reaches the bug.
2. A curl/HTTP script against a dev server on a non-production port.
3. A CLI call with a fixture input, diffed against a known-good output.
4. A headless browser script (Playwright) asserting on DOM, console or network.
5. A replay of a captured payload or event log through the code path in isolation.
6. A throwaway harness: the smallest subset of the system that hits the code path.
7. A property/fuzz loop for "sometimes wrong" output.
8. A bisection harness for "worked before": `git bisect run <check>`.
9. A differential loop: same input through old and new version, diff the outputs.

**Tighten it**: faster (narrow scope, skip unrelated setup), sharper (assert the exact symptom), deterministic (pin time, seed randomness, isolate filesystem and network). For flaky bugs, raise the reproduction rate (loop it, parallelise, add stress) until it is debuggable.

**Done when** you can name one command, already run with its output shown, that is:
- [ ] **Red-capable**: drives the real code path and asserts the user's exact symptom.
- [ ] **Deterministic**: same verdict every run (or a pinned, high reproduction rate).
- [ ] **Fast**: seconds.
- [ ] **Unattended**: runs without a human.

Theory comes after this command exists. When you cannot build one, stop and say so: list what you tried and ask the user for access to the failing environment, a redacted artifact (log, trace, payload), or permission for temporary instrumentation.

## Phase 2: Reproduce and minimise

Run the loop and confirm it shows the failure the **user** described, not a nearby one. Capture the exact symptom.

Then cut inputs, callers, config and steps one at a time, re-running after each cut. **Done when** every remaining element is load-bearing: removing any one turns the loop green.

## Phase 3: Hypothesise

Write **3–5 ranked hypotheses**, each falsifiable: "If X is the cause, then changing Y makes the bug disappear." A hypothesis with no prediction is a vibe: sharpen it or drop it.

Show the ranked list to the user before testing. They often re-rank instantly ("we changed #3 yesterday"). Continue with your ranking when they are away.

## Phase 4: Instrument

Each probe tests one prediction. Change one variable at a time.
- Prefer a debugger or REPL; otherwise targeted logs at the boundaries that separate hypotheses.
- Tag every debug log with a unique prefix, e.g. `[DEBUG-a4f2]`, so cleanup is one grep.
- Performance: measure a baseline first (timer, profiler, query plan), then bisect.

## Phase 5: Fix with a regression test

Find the **correct seam**: one where a test reproduces the real bug pattern as it happens at the call site. When the only available seam is too shallow to reproduce it, record that as a finding: the architecture is blocking the bug from being locked down.

With a correct seam, follow the `ordo:tdd` skill:
1. Turn the minimised repro into a failing test. Watch it go red.
2. Apply the fix (Tier 1+ fixes go to the `ordo:dev` agent with the test as the verify step; skipped when `ordo dev_helper_tier1` or `ordo dev_helper_tier2` is off for that tier: you write the fix yourself, test-first; switch rule: `ordo:workflow`).
3. Watch it go green.
4. Re-run the Phase 1 loop on the original, un-minimised scenario.

## Phase 6: Clean up

- [ ] The original repro no longer reproduces.
- [ ] The regression test passes, or the missing seam is documented.
- [ ] No `[DEBUG-` tags remain (`grep -rn "\[DEBUG-"`).
- [ ] Throwaway harnesses deleted or moved to a marked location.
- [ ] The confirmed hypothesis is stated in the commit message, so the next person learns it.
