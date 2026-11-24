# Contributing

Pull requests are welcome. Please read this page first.

## Rules

- Keep pull requests small: one change, one purpose.
- Work test-first: write the failing test, then the code that makes it pass. The method is the `ordo:tdd` skill in `plugins/ordo/skills/tdd/`.
- All test scripts under `scripts/` must pass before you open the PR. Run them all with:

  ```bash
  for t in scripts/test-*.sh; do bash "$t" || echo "FAILED: $t"; done
  ```

- Be kind: the community follows `CODE_OF_CONDUCT.md`.
- Contributions are licensed under the MIT licence of this repository (see `LICENSE`). There is no contributor agreement.
- Every pull request is reviewed and may be rejected if it does not fit the plugin's philosophy and purpose, which the opening of the README describes (process sized by tier, bounded review rounds, one goal at a time, rules backed by evals). Review speed is not promised.

## Pull requests

The public repository is only an export of the maintainer's source repository, so nothing is merged on GitHub. Accepted pull requests are applied by the maintainer in the source repository and shipped in the next release with credit: a `Co-Authored-By:` line with the contributor's GitHub noreply address, never a private one. The pull request is then closed with a link to that release commit. Because the public repository is rewritten from the source at each export, anything changed only on GitHub (an automated update, a web edit) is undone by the next export.

## Testing from a checkout

To try your checkout as the installed plugin, add it as a local marketplace instead of the published one: `claude plugin marketplace add <path to your checkout>` and then `claude plugin install ordo@ordo-marketplace`. Restart Claude Code after changing plugin files. `claude plugin validate .` checks the manifests.

## Test scripts

All free: they read repo files or fixtures only and make no model call.

- `scripts/test-release.sh`: pins the README, CHANGELOG and plugin text, the manifests, counts and licence files.
- `scripts/test-guard-bash.sh`: the Bash guard hook, stdin samples only.
- `scripts/test-goal-hook.sh`: the SessionStart goal hook.
- `scripts/test-stall-check.sh`: the helper watch script `plugins/ordo/skills/workflow/stall-check.sh`. A live run of a hung helper is not part of the tests.
- `scripts/test-eval-audit.sh`, `scripts/test-eval-plan-graders.sh`, `scripts/test-run-eval-suite.sh`: the eval tooling below.
- `scripts/test-ci-workflow.sh`: the CI workflow.

## Evals

Evals run the model and cost money: plan one with the `ordo:eval-plan` skill and get the maintainer's yes first. Never run them as part of a normal change.

- Running the evals: `claude plugin eval plugins/ordo`, in separate invocations by tag because the grants differ per invocation. `ba-reads-in-full`, `ba-uses-readers`, `ba-reader-mismatch`, `ba-claude-md-threshold`, `ba-global-claude-md`, `ba-global-only-small`, `ba-brief-beats-claude-md`, `ba-resends-short-read`, `reader-extracts-file`, `reader-extracts-fallback`, `refine-user-facing` (tag `trigger`), `refine-unreadable-file` (the only case with tag `refine-read`) and `po-reads-in-full` need `--scaffold`. `reader-extracts-file` (tag `reader-write`) needs `--allow-tools Write`. `ba-reads-in-full`, `ba-uses-readers`, `ba-reader-mismatch`, `ba-claude-md-threshold`, `ba-global-claude-md`, `ba-global-only-small`, `ba-brief-beats-claude-md` and `ba-resends-short-read` (tag `ba-readers`) need `--allow-tools Bash`, because the BA measures the reading set with it. `hook-blocks-rebase`, `eval-plan-before-run`, `eval-plan-after-run` and `retro-proposes-only` (tag `bash-skills`) need `--scaffold` and `--allow-tools Bash`: Claude must be able to attempt the Bash call for the hook's deny to be observed, and for the no-run and no-write graders to be able to fail. `dev-dispatch-report` (tag `dev-agent`) needs `--scaffold` and `--allow-tools Bash`, `--allow-tools Edit` and `--allow-tools Write`: the dispatched `ordo:dev` agent must be able to run the tests and edit files in the scaffolded project. `qa-fails-unmet-criterion` (tag `bash-skills`) and `diagnose-before-code` (tag `bash-skills`) need `--scaffold` and `--allow-tools Bash`: the dispatched `ordo:qa` agent runs the tests, and the diagnose skill runs a repro command. `decision-writes-adr` (tag `reader-write`) needs `--scaffold` and `--allow-tools Write`: the ADR is written with the Write tool. `consult-panel-seats` (tag `dev-agent`) and `feedback-draft-not-sent` (tag `dev-agent`) take the same grants as `dev-dispatch-report`: the consult writes the plan file and edits `ROADMAP.md`, the skill behind `feedback-draft-not-sent` writes its draft to a temp file, and Bash must be allowed there so that an attempt to send could be observed, so its scaffold refuses to run when `GH_TOKEN`, `GITHUB_TOKEN` or `GH_ENTERPRISE_TOKEN` is set (unset them first). `grill-asks-one-round` (tag `trigger`) needs `--scaffold`. `retro-no-autotrigger` and `workflow-loads-without-claude-md` (tag `trigger`) need `--scaffold`. `side-request-now-or-park`, `question-plain-one-rec`, `round4-asks-user` and `round2-history-auto-runs` (tag `trigger`) and `round2-wording-not-blocking` and `round2-keep-still-blocks` (tag `po`) have no `scaffold_script`, so they need no `--scaffold`; the suite runs them in its `trigger` and `po` batches. `reader-extracts-fallback` (tag `reader-nowrite`) must run without Write, so never combine it with the Write grant. `ba-reader-mismatch` can fail about 1 run in 6 on `no-redispatch` with nothing wrong (green 5/6); under that stronger brief only `mismatch-note` guards the re-read rule (AC12), because `real-value` passes without it.
- Eval audit: `scripts/eval-audit.sh [RESULTS.json ...]` prints one row per case pooled across the files: `CASE RUNS PASS_RATE AVG_COST_USD AVG_DURATION_S FLAKE COST_RANK` (rank 1 = highest average cost). With no arguments it reads the newest `plugins/ordo/evals/results/suite-*` folder. It only lists and never edits; needs `jq`. Tests: `scripts/test-eval-audit.sh`.
- Whole suite in one go: `scripts/run-eval-suite.sh` runs every batch above plus the no-Agent batch with the right flags, checks that each case sits in exactly one batch, and prints one summary (`--dry-run` shows the commands, `--runs N`/`-j N` pass through, `--batch NAME` limits it). It adds `--scaffold` to every batch whose cases have a `scaffold_script`; tests: `scripts/test-run-eval-suite.sh`.
- AC17 (the BA has no `Agent` tool) is evaluated by `scripts/run-noagent-cases.sh`, which runs `plugins/ordo/evals-noagent/` against a temp copy of the plugin whose `ba.md` tools line lacks `Agent`; the case lives outside `evals/` because in the normal suite the BA has `Agent` and it would fail. Set `ORDO_ABLATE_FILE=<path>` to use another `ba.md` in the copy. Results and the HTML report land in `plugins/ordo/evals-noagent/results/` (git-ignored) unless you pass `--output-dir`.
