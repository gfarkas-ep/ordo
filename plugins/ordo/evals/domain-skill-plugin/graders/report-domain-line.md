---
type: regex
pattern: '^[^\w\n]*Not verified[*_`]*:[\s\S]*^[^\w\n]*Domain skills[*_`]*:[^\n]*(?<!not loaded:[\s*_`]{0,6})\bacme:house-style(?![\w-])'
target: last_message
match: contains
flags: m
---
