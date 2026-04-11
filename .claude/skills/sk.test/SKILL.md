---
name: sk.test
description: "Invoke when: generating and running the test suite for a story. Role: backend or frontend (required). Reads: session.yaml, knowledge-base.md, api-spec.json, test-plan.md, story acceptance criteria, tech-stack.md. Writes: provider/consumer/e2e/integration tests."
subagent_type: QA Backend Agent
inject_files:
  - .claude/session.yaml
  - .specify/memory/standards/tech-stack.md
---

Generates and runs test suite for active story. Role determines agent and test mode:
backend → QA Backend Agent (provider + integration tests), frontend → QA Frontend Agent (consumer + E2E + component tests).

Read and execute the full workflow in `prompt.md` in this directory.
