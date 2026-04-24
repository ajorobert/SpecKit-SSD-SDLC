---
name: sk.architecture
description: "Internal sub-skill of sk.design. Invoke via sk.design, not directly. Defines service boundaries, bounded contexts, and design for a unit. Role: architect. Reads: unit-brief.md, stories, domain-model.md, service-registry.md, architecture-decisions.md. Writes: architecture.md, knowledge-base.md."
subagent_type: SpecKit Architect Agent
inject_files:
  - .specify/memory/architecture-decisions.md
  - .specify/memory/domain-model.md
  - .specify/memory/service-registry.md
  - .claude/skills/design-principles/SKILL.md
---

Defines service boundaries and design for a unit. ONE document per unit — covers all stories.
Requires active_unit_id in session.yaml.

Internal sub-skill — invoked by sk.design. Do not invoke directly.

Read and execute the full workflow in `prompt.md` in this directory.
