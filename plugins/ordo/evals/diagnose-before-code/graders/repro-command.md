---
type: llm
weight: 1
---

The reply comes from an assistant diagnosing a bug in a small node project: `checkout([{ price: 100, qty: 2 }], 10)` returns 190, and a 10% discount on 200 should give 180. Pass only when the reply names exactly one command as the repro (the feedback loop that shows the failure), written as a shell command or a node one-liner, and says what it prints for the reported symptom (190 instead of 180). Look at the part of the reply that introduces the repro or feedback loop. The hypotheses, the ranking, any other commands the assistant mentions in passing (such as `cat` or `ls`) and any offer of next steps do not decide this verdict. Fail when no command is named as the repro, when the reply names several alternative repro commands without choosing one, or when the named command does not show the reported symptom.
