---
name: sk.plan
description: "Invoke when: creating a technical implementation plan for a story. Role: lead. Reads: session.yaml, architecture.md, data-model.md, api-spec.json, story-{ID}.md, tech-stack.md. Writes: plan.md."
subagent_type: SpecKit Lead Agent
inject_files:
  - .claude/session.yaml
  - .specify/memory/standards/tech-stack.md
---

Creates technical implementation plan for a story.
Requires architecture.md to exist. Requires active_story_id in session.yaml.

Read and execute the full workflow in `prompt.md` in this directory.
