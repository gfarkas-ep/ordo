---
type: regex
pattern: '(?=[\s\S]*^[#*\s]*Plan(?:[*\s]*[—–:-]|[*\s]*$))(?=[\s\S]*^[#*\s]*Panel agrees on\b)(?=[\s\S]*^[#*\s]*Panel disagrees on\b)(?=[\s\S]*^[#*\s]*Changes I made to the plan\b)(?=[\s\S]*^[#*\s]*Open decisions for you\b)'
target: last_message
match: contains
flags: m
---
