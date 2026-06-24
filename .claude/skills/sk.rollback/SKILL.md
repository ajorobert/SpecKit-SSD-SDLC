---
name: sk.rollback
description: "Invoke when: reverting a shipped story — automated or manual rollback plan. Role: lead. Reads: session.yaml, stories/story-{Layer}-{ID}.md, 03-plan/{Project}/plan.md, migrations/. Writes: UNIT_DIR/rollback-plan.md. Hard block: requires shipped story."
subagent_type: SpecKit Lead Agent
inject_files:
  - .specify/memory/standards/data-standards.md
  - .specify/memory/architecture-decisions.md
  - .specify/memory/service-registry.md
preconditions:
  - story.status.current == shipped
---

Revert a shipped story — automated or manual rollback plan.
Requires story status = shipped (or explicitly overridden). Produces step-by-step rollback-plan.md covering code, migrations, config, and dependent services.

Read and execute the full workflow in `prompt.md` in this directory.
