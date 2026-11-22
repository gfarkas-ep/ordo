---
type: regex
pattern: '(?:^|\\n) {2}##\s*Questions(?:(?!\\n\s*#)(?:\\.|[^"\\]))*?\\n {2}[12]\.\s+\S'
flags: i
target: trace
match: not_contains
---
