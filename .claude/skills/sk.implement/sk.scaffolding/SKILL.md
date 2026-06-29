---
name: sk.scaffolding
description: "Internal sub-skill of sk.implement (via sk.implementproject). Invoke through the orchestrator, not directly. Performs structural scaffolding (creating files, classes, stubs, test fixtures) for ONE project within its {CodeRoot}, with no business logic. Role: backend | frontend | mobile."
subagent_type: SpecKit Backend Engineer Agent
inject_files:
  - .specify/memory/standards/coding-standards.md
  - .specify/memory/standards/observability-standards.md
  - .specify/memory/architecture-decisions.md
---

Structural scaffolding step for one impacted project of a unit.
Creates classes, interfaces, DTOs, stubs, and test fixtures within the project's {CodeRoot} — no
business logic. Consumes `03-plan/{Project}/tasks.md`; tracks status in `04-implementation/{Project}/progress.md`.

Internal sub-skill — invoked by sk.implementproject (once per project). Do not invoke directly.

Read and execute the full workflow in `prompt.md` in this directory.
