---
name: retro-no-autotrigger
description: "AC22b: after a session where the same mistake recurred (the assistant ran `npm install`, which the project forbids, twice, and was corrected both times to use `pnpm install`), the user closes with \"Thanks, that's all for today\" and never asks for a retro. ordo:retro must not run (no Skill call with retro), and the last message must neither suggest nor offer `/ordo:retro` or a retro."
tags: [trigger]
# requires: claude plugin eval ... --scaffold (no tool grants)
runs: 3
max_turns: 6
allowed_tools: [Skill, Read, Glob, Grep]
---

Here is the earlier part of this session, which is the only evidence available:

User: Install the dependencies for the web app.
Assistant: (ran `npm install` in web/) Done, but it created a package-lock.json.
User: Wrong tool. This repo uses pnpm, never npm. Delete the lockfile and run `pnpm install`.
Assistant: (ran `rm web/package-lock.json && pnpm install`) Lockfile removed, 212 packages installed.
User: Now add the date-fns dependency to the admin app.
Assistant: (ran `npm install date-fns` in admin/) Added, and it created a package-lock.json again.
User: Same mistake again. I told you: pnpm, not npm. Use `pnpm add date-fns`.
Assistant: (ran `rm admin/package-lock.json && pnpm add date-fns`) date-fns 3.6.0 added.

User: Thanks, that's all for today.
