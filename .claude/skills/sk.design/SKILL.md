---
name: sk.design
description: "Invoke when: running the full design pipeline for a unit in one shot, or scoped to specific projects. Role: architect (orchestrator). No args: full solution design — sk.architecture → [review gate] → sk.datamodel → [review gate] → sk.contracts in sequence; a story-declared ## Project section constrains it to those projects. Explicit project names (sk.design Backend.API … or --project) regenerate only the named 02-design/projects/ pages. Mode details in prompt.md. Each sub-skill runs in its own isolated context."
subagent_type: SpecKit Architect Agent
inject_files:
  - .claude/skills/governance/checkpoint-rules.md
  - .specify/memory/system-context.md
  - .specify/memory/architecture-decisions.md
  - .specify/memory/domain-model.md
  - .specify/memory/service-registry.md
---

Orchestrator skill — full design pipeline for a unit.
Invokes sk.architecture -> sk.datamodel -> sk.contracts in sequence.
Auto-generates the unit guide.yaml index after completion.
Each sub-skill runs in its own isolated context. Review gates enforced between phases.

Read and execute the full workflow in `prompt.md` in this directory.
