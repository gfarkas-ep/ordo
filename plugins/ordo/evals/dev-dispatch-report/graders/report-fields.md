---
type: regex
pattern: '(?=[\s\S]*^[^\w\n]*Task[*_`]*:)(?=[\s\S]*^[^\w\n]*Cycle[*_`]*:)(?=[\s\S]*^[^\w\n]*Verified[*_`]*:)(?=[\s\S]*^[^\w\n]*Files[*_`]*:)(?=[\s\S]*^[^\w\n]*Commit[*_`]*:)(?=[\s\S]*^[^\w\n]*Outside scope[*_`]*:)(?=[\s\S]*^[^\w\n]*Not verified[*_`]*:)'
target: last_message
match: contains
flags: m
---
