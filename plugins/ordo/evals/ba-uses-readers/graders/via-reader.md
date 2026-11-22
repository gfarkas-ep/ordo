---
type: regex
pattern: '#+\s*Read\b(?:(?!#+\s*Not verified)[\s\S])*?plotline-\w+\.md[`*]*:?\s*lines\s+1-(\d+)\s+of\s+\1\s*\(via reader\)'
flags: i
target: last_message
match: contains
---
