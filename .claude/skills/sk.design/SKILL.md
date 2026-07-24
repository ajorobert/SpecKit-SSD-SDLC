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

Project-selection priority (target projects chosen by the first source that applies):
  1. Explicit project names on the command line (`sk.design Backend.API [Admin.Panel …]`
     or `--project` form) → PROJECT mode: regenerates ONLY the named
     02-design/projects/{Project}.md pages; shared artifacts read-only, no other page touched.
     Names must exactly match unit-brief.md Impacted Projects / existing 02-design/projects/ files.
     Explicit args always override the story's `## Project` section.
  2. The unit's story.md `## Project` section (written by sk.story from Jira Components) →
     STORY-PROJECT mode: same scoped behaviour as PROJECT, projects sourced from the story.
  3. Neither → Full Solution Design: shared artifacts (architecture.md, impact-analysis.md,
     database-design.md, api-contract.md) plus one design page per impacted project.

Read and execute the full workflow in `prompt.md` in this directory.
