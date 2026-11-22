---
type: regex
pattern: 'expect[^\n]{0,60}(\d+\s?%|\d+\s*/\s*\d+)|(\d+\s?%|\d+\s*/\s*\d+)[^\n]{0,40}expect'
flags: i
target: last_message
match: contains
---
