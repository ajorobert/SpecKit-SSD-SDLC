---
name: sk.perf
description: "Invoke when: performance profiling and optimization — load test results or profiler output → diagnosis → tasks. Role: backend or frontend. Reads: session.yaml, profiler output, architecture.md. Writes: perf-findings.md, tasks.md."
subagent_type: SpecKit Backend Engineer Agent
inject_files:
  - .claude/session.yaml
  - .specify/memory/standards/coding-standards.md
  - .specify/memory/standards/observability-standards.md
  - .specify/memory/architecture-decisions.md
---

Performance profiling and optimization cycle.
Input: load test results or profiler output (required). Output: diagnosis, prioritised tasks, and measurable acceptance criteria.
Role determines agent: backend → SpecKit Backend Engineer Agent, frontend → SpecKit Frontend Engineer Agent.

Read and execute the full workflow in `prompt.md` in this directory.
