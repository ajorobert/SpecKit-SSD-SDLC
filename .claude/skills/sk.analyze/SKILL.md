---
name: sk.analyze
description: "Invoke when: running a cross-artifact consistency check for the active unit after implementation, before testing. Role: lead. READ-ONLY — no files written. Reads: architecture.md, all stories, api-spec.json, data-model.md, service-registry.md, domain-model.md, architecture-decisions.md."
subagent_type: SpecKit Lead Agent
inject_files:
  - .claude/session.yaml
  - .specify/memory/service-registry.md
  - .specify/memory/domain-model.md
  - .specify/memory/architecture-decisions.md
---

Cross-artifact consistency check. READ-ONLY — no files written.
Run after sk.implement, before sk.test. CRITICAL findings block sk.test and sk.verify.

Read and execute the full workflow in `prompt.md` in this directory.
