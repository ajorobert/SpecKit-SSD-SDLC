---
name: sk.contracts
description: "Internal sub-skill of sk.design. Invoke via sk.design, not directly. Defines API contracts, OpenAPI specs, and provider/consumer test plans for a unit. Role: architect. Reads: architecture.md, data-model.md, service-registry.md, api-standards.md. Writes: api-spec.json, test-plan.md, provider tests."
subagent_type: SpecKit Architect Agent
inject_files:
  - .specify/memory/service-registry.md
  - .specify/memory/standards/api-standards.md
  - .specify/memory/standards/tech-stack.md
  - .claude/skills/design-principles/SKILL.md
---

Defines API contracts and generates provider tests for a unit.
Requires architecture.md and data-model.md to exist.

Internal sub-skill — invoked by sk.design. Do not invoke directly.

Read and execute the full workflow in `prompt.md` in this directory.
