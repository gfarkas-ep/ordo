---
name: tdd
description: Test-first method for any behaviour change: seams, red-green loop, what makes a test worth keeping. Use before writing or changing code that alters behaviour, when fixing a bug, or when judging whether a test can catch a regression.
---

# Test-driven development

Adapted from mattpocock/skills (MIT, see LICENSE).

Every behaviour change ships with a test written first. Before reporting work done, check: does every new public function, endpoint and changed behaviour have a test that goes red without the change?

## A good test

Tests verify behaviour through public interfaces. The code behind them can change completely and the test still holds. A good test reads like a specification ("user can check out with a valid cart") and survives refactors because it ignores internal structure. Examples: [tests.md](tests.md). Mocking: [mocking.md](mocking.md).

## Seams

A **seam** is the public boundary you test at, where you observe behaviour without reaching inside. Tests live at seams.

**Test only at agreed seams.** Before the first test, write down the seams under test, each with one line on what it catches and what it misses.
- Main session: propose them with the tier line and proceed unless the user objects.
- Subagent: use the seams in your brief. When the brief names none, return the question to the architect.

## Anti-patterns

- **Implementation-coupled**: mocks internal collaborators, tests private methods, or verifies through a side channel (querying the database instead of the interface). The tell: it breaks on a refactor that kept behaviour.
- **Tautological**: the expected value is recomputed the way the code computes it, so it passes by construction. Expected values come from an independent source: a known literal, a worked example, the spec.
- **Horizontal slicing**: all tests first, then all code. Bulk tests verify imagined behaviour. Work in **vertical slices**: one test, one implementation, repeat, each test a **tracer bullet** shaped by what the last cycle taught you.

## The loop

1. **Red**: write one failing test at an agreed seam. Run it and confirm it fails for the right reason (the missing behaviour, not an import or setup error). A test that passes before the change proves nothing: rewrite it.
2. **Green**: write the minimum code that passes it. Leave future tests to future cycles.
3. Repeat, one seam and one test per cycle.

Refactoring belongs to review, after the loop.

Run the targeted test file each cycle and the project's typecheck regularly. Run the full suite once at the end, or leave it to whoever owns it when the project says so.
