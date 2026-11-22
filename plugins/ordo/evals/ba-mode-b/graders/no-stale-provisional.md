---
type: regex
pattern: '\\n {2}-\s*AC\d+:(?:(?!\\n).)*provisional\W+(?:Q|question\s*)[12]\b'
flags: i
target: trace
match: not_contains
---
