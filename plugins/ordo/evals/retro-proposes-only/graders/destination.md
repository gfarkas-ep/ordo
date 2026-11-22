---
type: regex
pattern: '\bDestination\b\W{0,8}(?:the\s+)?(?:memory|CLAUDE\.md|LESSONS\.md)'
flags: i
target: last_message
match: contains
---
