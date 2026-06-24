---
name: sk.hotfix
description: "Invoke when: P0 incident fast path — emergency fix to production. Role: lead. Reads: session.yaml, stories/, 02-design/architecture.md. Writes: 03-plan/{Project}/plan.md, 04-implementation/{Project}/, src/**. 3-gate: plan → implement → ship (no full spec cycle)."
subagent_type: SpecKit Lead Agent
inject_files:
  - .specify/memory/standards/coding-standards.md
  - .specify/memory/standards/observability-standards.md
  - .specify/memory/architecture-decisions.md
---

P0 incident fast path. Bypasses sk.design (architecture / data-model / contracts).
3 hard gates: plan → implement → ship.
Requires a hotfix story (story_type: hotfix) in session.yaml.

Read and execute the full workflow in `prompt.md` in this directory.
