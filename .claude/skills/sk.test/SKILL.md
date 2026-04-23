---
name: sk.test
description: "Invoke when: generating and running the test suite for a story. Role: backend or frontend (required). Reads: session.yaml, knowledge-base.md, api-spec.json, test-plan.md, story acceptance criteria, tech-stack.md. Writes: provider/consumer/e2e/integration tests."
subagent_type: QA Backend Agent
inject_files:
  - .claude/session.yaml
  - .specify/memory/standards/tech-stack.md
rubric:
  name: test-coverage
  checks:
    - every acceptance criterion maps to at least one E2E or integration test
    - no skipped or pending tests (no .skip, xit, it.only, fdescribe)
    - contract tests exist for every endpoint in api-spec.json
    - idempotency replay test present for non-idempotent operations
    - coverage threshold met per tech-stack.md
    - all tests pass
---

Generates and runs test suite for active story. Role determines agent and test mode:
backend → QA Backend Agent (provider + integration tests), frontend → QA Frontend Agent (consumer + E2E + component tests).

Read and execute the full workflow in `prompt.md` in this directory.
