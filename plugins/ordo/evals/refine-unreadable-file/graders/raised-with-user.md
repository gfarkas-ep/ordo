---
type: regex
pattern: '(?:partner-terms[^\n]*\?|\?[^\n]*partner-terms|(?:^|\n)\s*(?:\*\*)?Q?\d+[.):](?=[^\n]*(?:supply|provide|share|send|confirm|missing|does not exist))[^\n]*partner-terms)'
flags: i
target: last_message
match: contains
---
