---
name: sk.ship
description: "Invoke when: creating a PR and shipping a story after all quality gates pass. Role: lead. Reads: session.yaml, story-{ID}.md, service-registry.md. Requires: sk.verify PASS, test-status=pass, security-status=clear."
subagent_type: SpecKit Lead Agent
inject_files:
  - .specify/memory/service-registry.md
preconditions:
  - story.verify-status == PASS
  - story.test-status == pass
  - story.security-status != BLOCKED
---

Quality-gated release. Runs sk.verify before proceeding.
Hard blocks: sk.verify FAIL, security-status=BLOCKED, test-status≠pass.

Read and execute the full workflow in `prompt.md` in this directory.
