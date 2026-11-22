---
type: regex
pattern: '(?:^|\\n)\s*##\s*Questions(?:(?!\\n\s*#)(?:\\.|[^"\\]))*?\\n\s*1\.(?:(?!\\n).)*Recommended:(?:(?!\\n\s*#)(?:\\.|[^"\\]))*?\\n\s*2\.(?:(?!\\n).)*Recommended:'
flags: i
target: trace
match: contains
---
