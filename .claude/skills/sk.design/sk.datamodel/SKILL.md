---
name: sk.datamodel
description: "Internal sub-skill of sk.design. Invoke via sk.design, not directly. Designs data entities, schema strategy, and access patterns for a unit. Role: architect. Reads: architecture.md, domain-model.md, data-standards.md. Writes: data-model.md, domain-model.md (updated)."
subagent_type: SpecKit Architect Agent
inject_files:
  - .claude/session.yaml
  - .specify/memory/domain-model.md
  - .specify/memory/standards/data-standards.md
  - .claude/skills/design-principles/SKILL.md
---

Defines data model for a unit. ONE document per unit.
Requires active_unit_id in session.yaml and architecture.md to exist.

Internal sub-skill — invoked by sk.design. Do not invoke directly.

Read and execute the full workflow in `prompt.md` in this directory.
