---
type: regex
pattern: '(abort|stop)[^\n]{0,100}(\$\s?\d|\d+\s*(of|/)\s*\d+|fail|error|time)'
flags: i
target: last_message
match: contains
---
