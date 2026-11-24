---
name: improve-no-autostart
description: "AC14: after a session where the same ordo behaviour was corrected twice (the assistant ran the code reviewer on a one-word README change, and was told Tier 0 changes get no review), the user closes with \"Thanks, that's all for today\" and never asks to improve ordo. ordo:improve must not start (no Skill call with improve), ordo:coach must not be dispatched, and the last message must not offer ordo:improve. Negative control: improve-near-miss. No tool grants needed."
tags: [trigger]
# requires: claude plugin eval ... --scaffold (no tool grants)
runs: 3
max_turns: 6
allowed_tools: [Skill, Agent, Read, Glob, Grep]
---

Here is the earlier part of this session, which is the only evidence available:

User: Change the README heading "## Install" to "## Installation".
Assistant: (changed the heading, then dispatched ordo:code-reviewer on the one-word change) The reviewer APPROVED it.
User: That was a Tier 0 change. A direct "change X to Y" on doc wording needs no review. Do not run the reviewer for it.
Assistant: Understood, no review for Tier 0 changes.
User: Now change "## Usage" to "## Using acme".
Assistant: (changed the heading, then dispatched ordo:code-reviewer again) The reviewer APPROVED it.
User: Same mistake again. No reviewer for a heading change. I told you.

User: Thanks, that's all for today.
