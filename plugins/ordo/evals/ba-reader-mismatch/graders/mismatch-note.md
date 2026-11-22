---
type: regex
pattern: '#+\s*Not verified(?:(?!\n-{3})[\s\S])*?(?:mismatch|does not match|do not match|differs|discrepan|45[\s-]*days?)'
flags: i
target: last_message
match: contains
---
