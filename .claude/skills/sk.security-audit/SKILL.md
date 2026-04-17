---
name: sk.security-audit
description: "Invoke when: performing a security audit of implementation for a story. Role: security. Reads: session.yaml, knowledge-base.md, src/**, api-spec.json, architecture-decisions.md, story-{ID}.md. Writes: security-audit.md. Evaluates OWASP Top 10 + STRIDE."
subagent_type: Security Agent
inject_files:
  - .claude/session.yaml
  - .specify/memory/architecture-decisions.md
---

Security audit: OWASP Top 10 + STRIDE threat modeling.
Verdict: CLEAR | CONDITIONAL | BLOCKED. CRITICAL findings block story progression.

Read and execute the full workflow in `prompt.md` in this directory.
