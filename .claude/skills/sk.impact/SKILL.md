---
name: sk.impact
description: "Invoke when: assessing blast radius of proposed work before starting, determining risk level and checkpoint mode. Role: architect. Reads: system-context.md, service-registry.md, domain-model.md. Writes: impact-{date}-{NNN}.md."
subagent_type: SpecKit Architect Agent
inject_files:
  - .specify/memory/system-context.md
  - .specify/memory/service-registry.md
  - .specify/memory/domain-model.md
  - .claude/skills/governance/SKILL.md
---

Assesses blast radius of proposed work before starting. Run before sk.specify for high-risk changes.

Read and execute the full workflow in `prompt.md` in this directory.
