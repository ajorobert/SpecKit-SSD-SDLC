---
name: sk.codegen
description: "Internal sub-skill of sk.implement (via sk.implementproject). Invoke through the orchestrator, not directly. Implements business logic inside stubs created by sk.scaffolding for ONE project within its {CodeRoot}. Role: backend | frontend | mobile."
subagent_type: SpecKit Backend Engineer Agent
inject_files:
  - .specify/memory/standards/coding-standards.md
  - .specify/memory/standards/observability-standards.md
  - .specify/memory/architecture-decisions.md
---

Business logic implementation step for one impacted project of a unit.
Implements the rules, conditions, transformations, and validations inside the structures scaffolded
within the project's {CodeRoot}. Executes `03-plan/{Project}/tasks.md`; tracks status in
`04-implementation/{Project}/progress.md`.

Internal sub-skill — invoked by sk.implementproject (once per project). Do not invoke directly.

Read and execute the full workflow in `prompt.md` in this directory.
