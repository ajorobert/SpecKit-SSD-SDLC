---
name: sk.codegen
description: "Internal sub-skill of sk.implement. Invoke via sk.implement, not directly. Implements business logic inside stubs created by sk.scaffolding. Role: backend or frontend."
subagent_type: SpecKit Backend Engineer Agent
inject_files:
  - .specify/memory/standards/coding-standards.md
  - .specify/memory/standards/observability-standards.md
  - .specify/memory/architecture-decisions.md
---

Business logic implementation step.
Implements the rules, conditions, transformations, and validations inside existing structures.
Requires active_story_id in session.yaml.

Internal sub-skill — invoked by sk.implement. Do not invoke directly.

Read and execute the full workflow in `prompt.md` in this directory.
