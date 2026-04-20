---
name: sk.scaffolding
description: "Internal sub-skill of sk.implement. Invoke via sk.implement, not directly. Performs structural scaffolding (creating files, classes, stubs, test fixtures) with no business logic. Role: backend or frontend."
subagent_type: SpecKit Backend Engineer Agent
inject_files:
  - .claude/session.yaml
  - .specify/memory/standards/coding-standards.md
  - .specify/memory/standards/observability-standards.md
  - .specify/memory/architecture-decisions.md
---

Structural scaffolding step.
Creates classes, interfaces, DTOs, stubs, and test fixtures without business logic.
Requires active_story_id in session.yaml.

Internal sub-skill — invoked by sk.implement. Do not invoke directly.

Read and execute the full workflow in `prompt.md` in this directory.
