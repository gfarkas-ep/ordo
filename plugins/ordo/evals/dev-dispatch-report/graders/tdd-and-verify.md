---
type: llm
weight: 1
---

The reply relays the report of a developer agent that implemented a small task in a node project. Pass only when the report shows both: (1) a test was written first and seen to fail before the code change (a red run is named, with its failure line), and (2) the verify command from the brief, `sh test.sh`, was run after the change and passed, with a count or result shown. The report's `Cycle:` line carries (1) (for example "red confirmed (<failure text>)") and its `Verified:` line carries (2) (for example "`sh test.sh` -> ok 2 passed"). The `Not verified:` list names things the agent did not check; it is expected in every report and does not decide this verdict. Fail when the report shows only code written, a test that never failed first, or a verify command that was not run.
