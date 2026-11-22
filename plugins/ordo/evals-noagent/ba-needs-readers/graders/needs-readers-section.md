---
type: regex
pattern: '##\s*Needs readers(?=(?:(?!\n## )[\s\S])*plotline-boards)(?=(?:(?!\n## )[\s\S])*plotline-members)(?=(?:(?!\n## )[\s\S])*plotline-notifications)(?=(?:(?!\n## )[\s\S])*plotline-billing)(?=(?:(?!\n## )[\s\S])*plotline-exports)'
target: last_message
match: contains
---
