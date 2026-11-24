---
type: regex
pattern: '❓[^\n]*\bQ\d+\b(?:(?!➡|❓)[\s\S])*(?=❓|$)'
target: last_message
match: not_contains
---
