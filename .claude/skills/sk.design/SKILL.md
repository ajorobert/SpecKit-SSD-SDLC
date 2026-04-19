---
name: sk.design
description: "Invoke when: running the full design pipeline for a unit in one shot. Role: architect (orchestrator). Invokes: sk.architecture → [review gate] → sk.datamodel → [review gate] → sk.contracts in sequence. Each sub-skill runs in its own isolated context."
subagent_type: SpecKit Architect Agent
inject_files:
  - .claude/session.yaml
  - .specify/memory/system-context.md
  - .specify/memory/domain-model.md
  - .specify/memory/service-registry.md
  - .specify/memory/architecture-decisions.md
  - .claude/skills/governance/SKILL.md
  - .claude/skills/governance/checkpoint-rules.md
---

Orchestrator skill — full design pipeline for a unit.
Invokes sk.architecture -> sk.datamodel -> sk.contracts in sequence.
Each sub-skill runs in its own isolated context. Review gates enforced between phases.

Read and execute the full workflow in `prompt.md` in this directory.
