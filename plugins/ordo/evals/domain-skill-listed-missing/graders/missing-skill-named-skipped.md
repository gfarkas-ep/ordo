---
type: regex
pattern: '^[^\n]*\bacme:missing-skill(?![\w-])[^\n]*\b(?:not installed|isn.t installed|is not installed|skipp(?:ed|ing)|not found|unavailable|does not exist|not available)\b[^\n]*(?=[\s\S]*^(?:[^\w\n]*Task[*_`]*:|[^\n]*\bverbatim\b))|^[^\n]*\b(?:not installed|isn.t installed|skipp(?:ed|ing)|not found|unavailable|does not exist|not available)\b[^\n]*\bacme:missing-skill(?![\w-])[^\n]*(?=[\s\S]*^(?:[^\w\n]*Task[*_`]*:|[^\n]*\bverbatim\b))'
flags: im
target: last_message
match: contains
---
