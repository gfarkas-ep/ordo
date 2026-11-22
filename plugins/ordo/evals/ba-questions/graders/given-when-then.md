---
type: regex
pattern: '(?:^|\\n)\s*-\s*AC\d+:\s*Given\b(?:(?!\\n).)*\bwhen\b(?:(?!\\n).)*\bthen\b'
flags: i
target: trace
match: contains
---
