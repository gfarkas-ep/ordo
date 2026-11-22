---
type: regex
pattern: '\bnow\b(?:(?![.!;]\s)[^?\n]){0,100}\bor\b(?:(?![.!;]\s)[^?\n]){0,30}\bpark(?:ed|ing)?\b(?:(?![.!;]\s)[^?\n]){0,120}\?|\bpark(?:ed|ing)?\b(?:(?![.!;]\s)[^?\n]){0,120}\bor\b(?:(?![.!;]\s)[^?\n]){0,40}\bnow\b(?:(?![.!;]\s)[^?\n]){0,60}\?'
target: last_message
match: contains
flags: i
---
