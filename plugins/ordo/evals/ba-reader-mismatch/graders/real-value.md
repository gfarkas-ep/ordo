---
type: regex
pattern: '#+\s*Spec\b(?:(?!#+\s*(?:Needs readers|Read)\b)[\s\S])*?180[\s-]*days?'
flags: i
target: last_message
match: contains
---
