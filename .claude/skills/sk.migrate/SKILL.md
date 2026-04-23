---
name: sk.migrate
description: "Invoke when: database migration lifecycle — expand/contract, rollback plan, migration test. Role: backend. Reads: session.yaml, data-model.md, architecture.md. Writes: migrations/**, rollback-plan.md."
subagent_type: SpecKit Backend Engineer Agent
inject_files:
  - .claude/session.yaml
  - .specify/memory/standards/data-standards.md
  - .specify/memory/standards/coding-standards.md
  - .claude/skills/postgresql-patterns/SKILL.md
preconditions:
  - file_exists: specs/intents/*/units/*/data-model.md
---

Database migration lifecycle using expand/contract pattern.
Requires data-model.md. Produces migration files, rollback plan, and migration tests.

Read and execute the full workflow in `prompt.md` in this directory.
