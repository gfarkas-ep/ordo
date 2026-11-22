---
type: regex
pattern: '(?:^|\n)[^\n]*(?:\bOpus\b|\bFable\b|higher model|stronger model|approach|\bpark)[^\n]*\?\s*\n+\s*(?:\*\*)?Recommend(?:ed)?:|(?:^|\n)\s*(?:\*\*)?Recommend(?:ed)?:?(?:\*\*)?[^\n]*(?:\bOpus\b|\bFable\b|higher model|stronger model|approach|\bpark)'
target: last_message
match: contains
flags: i
---
