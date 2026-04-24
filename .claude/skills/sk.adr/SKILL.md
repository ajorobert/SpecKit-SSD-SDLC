---
name: sk.adr
description: "Invoke when: creating an Architecture Decision Record for a cross-service or significant unit-level decision. Role: architect. Reads: session.yaml, architecture-decisions.md. Writes: history/adr/ADR-{NNN}.md, architecture-decisions.md (index)."
subagent_type: SpecKit Architect Agent
inject_files:
  - .specify/memory/architecture-decisions.md
---

Creates an Architecture Decision Record. Requires at least 2 alternatives and both positive and negative consequences.

Read and execute the full workflow in `prompt.md` in this directory.
