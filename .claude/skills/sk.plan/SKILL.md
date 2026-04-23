---
name: sk.plan
description: "Invoke when: creating a technical implementation plan. Role: lead (orchestrator). Runs at unit level. Invokes: sk.planstory (for each story) → sk.analyze. Reads: session.yaml, architecture.md, data-model.md, api-spec.json, tech-stack.md."
subagent_type: SpecKit Lead Agent
inject_files:
  - .specify/memory/standards/tech-stack.md
  - .claude/skills/governance/SKILL.md
  - .claude/skills/governance/checkpoint-rules.md
---

Orchestrator skill — full planning pipeline for a unit.
Invokes sk.planstory for each specified story, then sk.analyze to validate constraints.
Each sub-skill runs in its own isolated context.

Read and execute the full workflow in `prompt.md` in this directory.
