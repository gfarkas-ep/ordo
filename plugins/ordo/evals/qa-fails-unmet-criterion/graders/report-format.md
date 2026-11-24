---
type: regex
pattern: '(?=[\s\S]*^[^\w\n]*Verdict\b)(?=[\s\S]*^[^\w\n]*Coverage\b)(?=[\s\S]*^[^\w\n]*Test quality\b)(?=[\s\S]*^[^\w\n]*Checks\b)(?=[\s\S]*^[^\w\n]*Issues\b)(?=[\s\S]*^[^\w\n]*Not verified\b)'
target: last_message
match: contains
flags: m
---
