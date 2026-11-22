---
type: regex
pattern: '(?:^|\n)\s*(?:#+\s*)?(?:\*\*)?1[.)](?:(?!\n\s*(?:#+\s*)?(?:\*\*)?2[.)]|venv/bin/pytest)[\s\S]){0,800}?(?:force|push)[\s\S]*?\n\s*(?:#+\s*)?(?:\*\*)?2[.)][\s\S]{0,600}?venv/bin/pytest'
flags: i
target: last_message
match: contains
---
