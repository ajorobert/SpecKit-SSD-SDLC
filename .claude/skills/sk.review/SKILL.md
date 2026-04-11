---
name: sk.review
description: "Invoke when: performing spec-aware code review after implementation. Role: backend or frontend (required). Reads: architecture.md, api-spec.json, architecture-decisions.md, coding-standards.md. Writes: review-{story-id}.md."
subagent_type: SpecKit Backend Engineer Agent
inject_files:
  - .claude/session.yaml
  - .specify/memory/architecture-decisions.md
  - .specify/memory/standards/coding-standards.md
  - .specify/memory/standards/observability-standards.md
---

Spec-aware code review: validates against bounded context, contracts, and ADRs.
Role determines agent: backend → SpecKit Backend Engineer Agent, frontend → SpecKit Frontend Engineer Agent.

Read and execute the full workflow in `prompt.md` in this directory.
