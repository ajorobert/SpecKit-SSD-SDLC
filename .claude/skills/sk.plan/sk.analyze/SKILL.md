---
name: sk.analyze
description: "Internal sub-skill of sk.plan. Invoke via sk.plan, not directly. Runs a cross-artifact consistency check for the active unit. Role: lead. READ-ONLY — no files written. Reads: architecture.md, all stories, api-spec.json, data-model.md, service-registry.md, domain-model.md, architecture-decisions.md."
subagent_type: SpecKit Lead Agent
inject_files:
  - .specify/memory/service-registry.md
  - .specify/memory/domain-model.md
  - .specify/memory/architecture-decisions.md
---

Cross-artifact consistency check. READ-ONLY — no files written.
Runs as the final phase of sk.plan. CRITICAL findings block implementation.

Internal sub-skill — invoked by sk.plan orchestrator. Do not invoke directly.

Read and execute the full workflow in `prompt.md` in this directory.
