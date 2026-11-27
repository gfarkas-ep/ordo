---
type: regex
pattern: '(?:"file_path"\s*:\s*"[^"]*tests/[\w.-]+"|(?:>>?|\btee\b)\s*\S*tests/[\w.-]+)[^}]*?(?:slug\.sh\s+\\*["''](?:\s+\S|[^"''\\\n]*\S\s+\\*["''])|\w+=\\*["''](?:\s+\S|[^"''\\\n]*\S\s+\\*["''])[^}]*?slug\.sh\s+\\*["'']?\$)'
target: trace
match: contains
---
