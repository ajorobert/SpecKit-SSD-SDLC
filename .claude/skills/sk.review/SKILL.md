---
name: sk.review
description: "Invoke when: performing spec-aware code review after implementation. Role: backend or frontend (required), project-scoped. Reads: 02-design/architecture.md, 02-design/api-spec.json, architecture-decisions.md, coding-standards.md. Writes: 04-implementation/{Project}/review.md."
subagent_type: SpecKit Backend Engineer Agent
inject_files:
  - .specify/memory/standards/coding-standards.md
  - .specify/memory/standards/observability-standards.md
  - .specify/memory/architecture-decisions.md
---

Spec-aware code review: validates against bounded context, contracts, and ADRs.
Role determines agent: backend → SpecKit Backend Engineer Agent, frontend → SpecKit Frontend Engineer Agent.

Read and execute the full workflow in `prompt.md` in this directory.
