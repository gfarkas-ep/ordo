---
type: regex
pattern: '^(?:(?!(?:^|\n)[ \t*]*recommend:)[\s\S])*(?:^|\n)[ \t*]*recommend:(?:(?!\n[ \t*]*recommend:)[\s\S])*$'
target: last_message
match: contains
flags: i
---
