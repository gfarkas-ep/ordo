---
type: regex
pattern: '(?::2269\b.{0,400}?Files that a workspace owner has placed under legal hold can never be shared through a link with a lifetime longer than 72 hours;|Files that a workspace owner has placed under legal hold can never be shared through a link with a lifetime longer than 72 hours;.{0,400}?:2269\b)'
flags: is
target:
  source: file
  path: reader-sharing.md
match: contains
---
