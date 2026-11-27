---
type: regex
pattern: '^[^\w\n]*Verified[*_`]*:[^\n]*\b\d+ passed\b'
flags: im
target: last_message
match: contains
---
