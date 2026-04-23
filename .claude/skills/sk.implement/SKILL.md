---
name: sk.implement
description: "Invoke when: generating tasks and executing implementation for a story. Role: backend or frontend (required — determines agent). Reads: session.yaml, plan.md, architecture.md, contracts, coding-standards.md. Writes: tasks.yaml, src/**."
subagent_type: SpecKit Backend Engineer Agent
inject_files:
  - .specify/memory/standards/coding-standards.md
  - .specify/memory/standards/observability-standards.md
  - .specify/memory/architecture-decisions.md
---

Generates task breakdown and executes implementation phase-by-phase. Role determines agent: backend → SpecKit Backend Engineer Agent, frontend → SpecKit Frontend Engineer Agent.
Requires plan.md. Refine mode activated if review-{story-id}.md exists.

Read and execute the full workflow in `prompt.md` in this directory.
