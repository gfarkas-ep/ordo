---
type: regex
pattern: '(?:^|\\n)\s*##\s*Escalations(?:(?!\\n\s*#)(?:\\.|[^"\\]))*?(?:C4|notification)'
flags: i
target: trace
match: contains
---
