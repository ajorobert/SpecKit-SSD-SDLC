---
name: sk.implement
description: "Invoke when: generating tasks and executing implementation for a story, project-scoped (--project). Role: backend or frontend (required — determines agent). Reads: session.yaml, 03-plan/{Project}/plan.md, 02-design/. Writes: 04-implementation/{Project}/{implementation,progress,validation}.md, src/**."
subagent_type: SpecKit Backend Engineer Agent
inject_files:
  - .specify/memory/standards/story-lifecycle.md
  - .specify/memory/standards/coding-standards.md
  - .specify/memory/standards/observability-standards.md
  - .specify/memory/architecture-decisions.md
---

Generates task breakdown and executes implementation phase-by-phase, scoped to one project. Role determines agent: backend → SpecKit Backend Engineer Agent, frontend → SpecKit Frontend Engineer Agent.
Requires 03-plan/{Project}/plan.md. Refine mode activated if a prior validation/review exists.

Read and execute the full workflow in `prompt.md` in this directory.
