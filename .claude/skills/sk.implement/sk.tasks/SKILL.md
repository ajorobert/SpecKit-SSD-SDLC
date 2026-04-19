---
name: sk.tasks
description: "Internal sub-skill of sk.implement. Invoke via sk.implement, not directly. Generates actionable task breakdown from a plan for a story. Role: lead."
subagent_type: SpecKit Lead Agent
inject_files:
  - .claude/session.yaml
---

Generates phased task breakdown for a story. TDD order: tests before implementation.
Requires plan.md and approved checkpoint (if confirm/validate mode).

Internal sub-skill — invoked by sk.implement. Do not invoke directly.

Read and execute the full workflow in `prompt.md` in this directory.
