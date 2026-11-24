---
type: regex
pattern: '(?=[\s\S]*^[^\w\n]*Title\b[*_`]*:)(?=[\s\S]*^[ \t>]*###\s+Plugin version\b)(?=[\s\S]*^[ \t>]*###\s+Claude Code version\b)(?=[\s\S]*^[ \t>]*###\s+Operating system\b)(?=[\s\S]*^[ \t>]*###\s+Steps to reproduce\b)(?=[\s\S]*^[ \t>]*###\s+Expected result\b)(?=[\s\S]*^[ \t>]*###\s+Actual result\b)(?=[\s\S]*^[ \t>]*###\s+ordo switches and settings in use\b)'
target: last_message
match: contains
flags: m
---
