---
name: sk.uat
description: "Invoke when: performing user acceptance testing against story acceptance criteria. Role: frontend-qa. Reads: session.yaml, story-{ID}.md, test-plan.md consumer section. Writes: story test-status. Platform: web | mobile | admin."
subagent_type: QA Frontend Agent
inject_files:
  - .specify/memory/standards/tech-stack.md
---

User Acceptance Testing against story acceptance criteria. Frontend only.
Platform required: --platform web|mobile|admin. Tooling per tech-stack.md.

Read and execute the full workflow in `prompt.md` in this directory.
