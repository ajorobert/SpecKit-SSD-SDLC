---
name: sk.design
description: "Invoke when: running the full design pipeline for a unit in one shot, or regenerating specific project design pages only. Role: architect (orchestrator). No args: full solution design — sk.architecture → [review gate] → sk.datamodel → [review gate] → sk.contracts in sequence. With project names (sk.design Backend.API [Admin.Panel …] or --project): PROJECT mode — regenerates only the named 02-design/projects/ pages, shared artifacts untouched. Each sub-skill runs in its own isolated context."
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

Two execution modes:
- No project argument: Full Solution Design — shared artifacts (architecture.md,
  impact-analysis.md, database-design.md, api-contract.md) plus one design page per
  impacted project under 02-design/projects/.
- Project names given (`sk.design Backend.API [Admin.Panel …]` or `--project` form):
  PROJECT mode — regenerates ONLY the named 02-design/projects/{Project}.md pages;
  shared artifacts are read-only and no other project page is touched. Names must
  exactly match unit-brief.md Impacted Projects / existing 02-design/projects/ files.

Read and execute the full workflow in `prompt.md` in this directory.
