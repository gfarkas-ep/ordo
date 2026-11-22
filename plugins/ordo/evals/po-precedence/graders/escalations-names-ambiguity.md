---
type: regex
pattern: '(?:^|\\n)\s*##\s*Escalations(?:(?!\\n\s*#)(?:\\.|[^"\\]))*?(?:C4|reasonably strong)'
flags: i
target: trace
match: contains
---
