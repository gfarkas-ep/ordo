---
type: regex
pattern: '\b(?:idempoten\w*|upsert\w*|tombstone\w*)\b(?!["''”’]?(?:\s*\(|\s+[—–-]\s|\s+means\b|\s+meaning\b|\s*,?\s*i\.e\.|, which))'
target: last_message
match: not_contains
flags: i
---
