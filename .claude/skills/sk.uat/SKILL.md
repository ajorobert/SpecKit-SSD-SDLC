---
name: sk.uat
description: "Invoke when: performing user acceptance testing against story acceptance criteria. Role: frontend-qa. Reads: session.yaml, 01-story/acceptance-criteria.md. Writes: 06-uat/{acceptance-result,user-flow-test,signoff}.md + story test-status. Platform: web | mobile | admin."
subagent_type: QA Frontend Agent
inject_files:
  - .specify/memory/standards/story-lifecycle.md
  - .specify/memory/standards/tech-stack.md
---

User Acceptance Testing against story acceptance criteria. Frontend only.
Platform required: --platform web|mobile|admin. Tooling per tech-stack.md.

Read and execute the full workflow in `prompt.md` in this directory.
