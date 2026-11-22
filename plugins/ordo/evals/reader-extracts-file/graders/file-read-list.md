---
type: regex
pattern: 'SHARING_DESIGN\.md[`*]*:?\s*lines\s+1-(233[34])\s+of\s+\1\b'
flags: i
target:
  source: file
  path: reader-sharing.md
match: contains
---
