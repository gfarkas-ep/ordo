---
type: regex
pattern: '(?:^|\\n) {2}##\s*Questions(?:(?!\\n\s*#)(?:\\.|[^"\\]))*?\\n {2}4\.(?:(?!\\n).)*(?:guest|account)'
flags: i
target: trace
match: contains
---
