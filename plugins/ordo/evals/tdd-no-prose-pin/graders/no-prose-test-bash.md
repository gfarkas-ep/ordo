---
type: tool_used
tool: Bash
input_match: '>>?\s*\S*(?:tests/[\w.-]+|test\.sh)\s*<<-?\s*\\*[''"]?(\w+)\\*[''"]?(?=\\n)(?:(?!\\n\1(?:\\n|"))[\s\S])*?(?:(?:\b|(?<=\\n))(?:grep|cat|awk|sed)\b|<)(?:\\"|[^\\])*RULES\.md|(?:\b|(?<=\\n))(?:grep|cat|awk|sed)\b(?:\\"|[^\\|;&])*RULES\.md(?:\\\\n|\\[n"]|[^\\;&])*(?:\|\s*tee\s+|>>?\s*)\S*(?:tests/[\w.-]+|test\.sh)|<<-?\s*\\*[''"]?(\w+)\\*[''"]?\s*>>?\s*\S*(?:tests/[\w.-]+|test\.sh)(?=\\n)(?:(?!\\n\2(?:\\n|"))[\s\S])*?(?:(?:\b|(?<=\\n))(?:grep|cat|awk|sed)\b|<)(?:\\"|[^\\])*RULES\.md'
min: 0
max: 0
---
