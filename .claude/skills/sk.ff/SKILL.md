---
name: sk.ff
description: "Invoke when: running the full Fast Forward pipeline from story capture to planning in one shot. Role: lead (orchestrator). Modes: sk.ff (feature) or sk.ff --bug (bug fix). Invokes: sk.specify → sk.clarify → sk.design (validate checkpoint only) → sk.plan in sequence."
subagent_type: SpecKit Lead Agent
inject_files:
  - .claude/session.yaml
  - .specify/memory/system-context.md
  - .specify/memory/standards/tech-stack.md
  - .claude/skills/governance/SKILL.md
  - .claude/skills/governance/checkpoint-rules.md
---

Orchestrator skill — Fast Forward pipeline.
Invokes sk.specify → sk.clarify → [sk.design] → sk.plan in sequence.
Each sub-skill runs in its own isolated context. Checkpoints respected between phases.

Read and execute the full workflow in `prompt.md` in this directory.
