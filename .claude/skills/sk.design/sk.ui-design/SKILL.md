---
name: sk.ui-design
description: "Internal sub-skill of sk.design. Invoke via sk.design, not directly. Designs the frontend surface for a unit — route/page tree, component architecture, state placement, API-consumption contracts, performance and accessibility strategy. Role: frontend. Reads: architecture.md, contracts/api-spec.json, contracts/test-plan.md, unit-brief.md, stories, domain-model.md. Writes: ui-model.md."
subagent_type: SpecKit Frontend Engineer Agent
inject_files:
  - .specify/memory/standards/coding-standards.md
  - .specify/memory/domain-model.md
  - .claude/skills/design-principles/SKILL.md
---

Defines the frontend UI model for a unit — page/route tree, component decomposition, state architecture, API-consumption types, performance and accessibility strategy. ONE document per unit — covers the frontend surface for all stories.

Consumes the architecture and API contracts the architect already produced. Does NOT redefine service boundaries, schema, or which endpoints exist — it elaborates how the frontend is structured and how it consumes those contracts.

Internal sub-skill — invoked by sk.design Phase 6 when frontend signals are present. Do not invoke directly.

Read and execute the full workflow in `prompt.md` in this directory.
