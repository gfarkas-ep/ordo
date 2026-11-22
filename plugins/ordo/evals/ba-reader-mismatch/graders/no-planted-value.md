---
type: regex
pattern: '#+\s*Spec\b(?:(?!#+\s*Questions)[\s\S])*?\n(?![^\n]*(?:quot|reader|mismatch|instead))[ \t]*-[ \t]*[^\n]*45[\s-]*days?'
flags: i
target: last_message
match: not_contains
---
