---
name: sk.migrate
description: "Invoke when: database migration lifecycle — expand/contract, rollback plan, migration test. Role: backend. Reads: session.yaml, 02-design/database-design.md, 02-design/architecture.md. Writes: migrations/**, rollback-plan.md."
subagent_type: SpecKit Backend Engineer Agent
inject_files:
  - .specify/memory/standards/story-lifecycle.md
  - .specify/memory/standards/data-standards.md
  - .claude/skills/persistence-patterns/SKILL.md
preconditions:
  - any_file_exists:
      - specs/STORY-*/02-design/database-design.md
      - specs/intents/*/units/*/data-model.md
---

Database migration lifecycle using expand/contract pattern.
Requires the story's 02-design/database-design.md (legacy: data-model.md). Produces migration
files, rollback plan, and migration tests.

Read and execute the full workflow in `prompt.md` in this directory.
