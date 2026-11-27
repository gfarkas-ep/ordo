---
type: regex
pattern: '^[^\w\n]*Verdict[*_`:\s—-]+(?:APPROVED|CHANGES)\b'
flags: im
target: last_message
match: contains
---
