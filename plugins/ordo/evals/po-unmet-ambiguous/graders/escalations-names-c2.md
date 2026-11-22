---
type: regex
pattern: '(?:^|\\n)\s*##\s*Escalations(?:(?!\\n\s*#)(?:\\.|[^"\\]))*?C2\b'
flags: i
target: trace
match: contains
---
