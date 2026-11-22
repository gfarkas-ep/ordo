---
type: regex
pattern: '(?:^|\\n) {2}##\s*Questions(?:(?!\\n\s*#)(?:\\.|[^"\\]))*?\\n {2}3\.(?:(?!\\n).)*(?:email|confirmation)'
flags: i
target: trace
match: contains
---
