---
name: sk.tasks
description: "Invoke when: generating actionable task breakdown from a plan for a story. Role: lead. Reads: session.yaml, plan.md, story frontmatter. Writes: tasks.md."
subagent_type: SpecKit Lead Agent
inject_files:
  - .claude/session.yaml
---

Generates phased task breakdown for a story. TDD order: tests before implementation.
Requires plan.md and approved checkpoint (if confirm/validate mode).

Read and execute the full workflow in `prompt.md` in this directory.
