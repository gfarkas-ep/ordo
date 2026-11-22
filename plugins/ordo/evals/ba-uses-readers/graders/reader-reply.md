---
type: regex
pattern: '(?:reader-[a-z0-9_-]+\.md|Report not written:)(?:(?!#+\s*Spec)[\s\S])*?plotline-\w+\.md[`*]*:?\s*lines\s+1-(\d+)\s+of\s+\1\b'
flags: i
target: trace
match: contains
---
