---
name: sk.implement
description: "Invoke when: executing implementation tasks for a story. Role: backend or frontend (required — determines agent). Reads: session.yaml, plan.md, tasks.md, architecture.md, contracts, coding-standards.md. Writes: src/**."
subagent_type: SpecKit Backend Engineer Agent
inject_files:
  - .claude/session.yaml
  - .specify/memory/standards/coding-standards.md
  - .specify/memory/standards/observability-standards.md
  - .specify/memory/architecture-decisions.md
---

Executes implementation tasks phase-by-phase. Role determines agent: backend → SpecKit Backend Engineer Agent, frontend → SpecKit Frontend Engineer Agent.
Requires plan.md and tasks.md. Refine mode activated if review-{story-id}.md exists.

Read and execute the full workflow in `prompt.md` in this directory.
