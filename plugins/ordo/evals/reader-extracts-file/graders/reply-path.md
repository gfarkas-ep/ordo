---
type: regex
pattern: 'reader-sharing\.md[\s\S]*SHARING_DESIGN\.md[`*]*:?\s*lines\s+1-(233[34])\s+of\s+\1\b'
flags: i
target: last_message
match: contains
---
