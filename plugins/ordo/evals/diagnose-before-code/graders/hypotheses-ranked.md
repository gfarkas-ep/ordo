---
type: llm
weight: 1
---

The reply comes from an assistant diagnosing a bug in a small node project (a 10% discount subtracted as 10 instead of taken as a percentage). Pass only when the reply gives a list of 3 to 5 hypotheses that is ranked (ordered most likely first, or each given an explicit rank or likelihood), and every hypothesis is falsifiable: it states a prediction, in the form "if X is the cause, then changing or checking Y makes the bug disappear" or an equivalent check whose result would rule it out. Look at the hypotheses list only. The repro command, the evidence lines, the order in which the assistant read files and any offer to test or fix next do not decide this verdict. Fail when there are fewer than 3 or more than 5 hypotheses, when they are not ranked, or when any hypothesis names no check or prediction that could prove it wrong.
