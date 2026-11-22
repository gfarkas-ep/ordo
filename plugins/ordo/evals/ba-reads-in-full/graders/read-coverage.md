---
type: regex
pattern: '(?:^|\\n)\s*-\s*\S*SHARING_DESIGN\.md[`*]*:?[`*]*\s*:?\s*lines\s+1-(23(?:3[3-9]|[4-9]\d))\s+of\s+\1\b'
flags: i
target: trace
match: contains
---
