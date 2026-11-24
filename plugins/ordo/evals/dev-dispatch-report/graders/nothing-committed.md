---
type: regex
pattern: '^[^\w\n]*Commit[*_`]*:[ \t*_`(—-]*(not requested|none|no commit|not committed|nothing|n/a)\b'
target: last_message
match: contains
flags: im
---
