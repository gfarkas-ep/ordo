---
type: regex
pattern: '(?:3[.):]|[Tt]hird|[Ss]tep 3)[^\n]{0,60}REFACTOR-27|[Gg]reen\W{1,20}(?:then\s+)?REFACTOR-27|[Gg]reen\b[^\n]{0,300}REFACTOR-27[^\n]{0,300}[Rr]epeat'
target: last_message
match: contains
---
