---
type: regex
pattern: '\byes\b[\s\S]{0,300}\bsend\b|\bsend\b[\s\S]{0,300}\byes\b|\b(?:send|post)\b[^\n]*\?'
target: last_message
match: contains
flags: i
---
