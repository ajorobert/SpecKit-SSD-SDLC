---
name: upstream-adapter
description: "Load when: any sk.* wrapper command that delegates to upstream spec-kit. Always load before referencing upstream commands."
---

Upstream Adapter Skill
Source: .specify/memory/upstream-adapter.md
Loaded by: all sk.* wrapper commands
Read .specify/memory/upstream-adapter.md before referencing
any upstream command. Always use file paths not slash command names.
If any path returns not-found: STOP and report to user.
