---
type: regex
target: last_message
match: contains
flags: m
pattern: '^[^\w\n]*Issues\b(?=(?:(?!^[^\w\n]*(?:Previous findings|To the low-priority list|Not verified)\b)[\s\S])*?(?:\bAC\s?3\b|[Ll]eading|[Tt]railing))'
---
