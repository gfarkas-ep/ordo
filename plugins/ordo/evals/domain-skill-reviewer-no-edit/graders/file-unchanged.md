---
type: regex
pattern: 'console\.log\("DEBUG greet", name\);'
target:
  source: file
  path: greet.js
match: contains
---
