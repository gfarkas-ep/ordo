---
type: regex
pattern: '^[^\w\n]*Verdict\b[^\w\n]*FAIL\b'
target: last_message
match: contains
flags: im
---
