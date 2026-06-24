---
name: sk.security-audit
description: "Invoke when: performing a security audit of implementation for a story. Role: security. Reads: session.yaml, 01-story/, 02-design/, 04-implementation/, src/**, architecture-decisions.md. Writes: 07-security-audit/{owasp-report,stride-review,dependency-scan,security-signoff}.md. Evaluates OWASP Top 10 + STRIDE + dependency scan."
subagent_type: Security Agent
inject_files:
  - .specify/memory/standards/story-lifecycle.md
  - .specify/memory/architecture-decisions.md
rubric:
  name: security-coverage
  checks:
    - every OWASP Top 10 category has a documented verdict
    - STRIDE categories (Spoofing, Tampering, Repudiation, Info-disclosure, DoS, Elevation) covered
    - no hardcoded secrets or credentials in scope
    - dependencies scanned for known CVEs
    - auth boundaries explicitly verified
    - every finding has severity (CRITICAL|HIGH|MEDIUM|LOW) and remediation
    - no CRITICAL findings unresolved
---

Security audit: OWASP Top 10 + STRIDE threat modeling.
Verdict: CLEAR | CONDITIONAL | BLOCKED. CRITICAL findings block story progression.

Read and execute the full workflow in `prompt.md` in this directory.
