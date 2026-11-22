---
type: regex
pattern: 'refund-policy[^\n]{0,80}(2\s*(of|/)\s*4|fail)'
flags: i
target: last_message
match: contains
---
