---
name: sk.plan
description: "Invoke when: creating a technical implementation plan. Role: lead (orchestrator). Project-scoped: --role/--project. Invokes: sk.planstory (per project) → sk.analyze. Writes: 03-plan/{ProjectName}/{plan,tasks,checklist,jira-subtask,estimation}.md."
subagent_type: SpecKit Lead Agent
inject_files:
  - .specify/memory/standards/story-lifecycle.md
  - .claude/skills/governance/checkpoint-rules.md
  - .specify/memory/standards/tech-stack.md
---

Orchestrator skill — project-scoped planning pipeline for the active story.
Plans each impacted project (03-plan/{ProjectName}/), then sk.analyze to validate constraints.
Each sub-skill runs in its own isolated context.

Read and execute the full workflow in `prompt.md` in this directory.
