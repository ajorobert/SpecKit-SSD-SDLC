Governance Skill
Loaded by: sk.verify, sk.ff, sk.impact
Files

checkpoint-rules.md  — complexity classification, checkpoint behaviour
quality-gates.md     — PASS/FAIL gate definitions per phase (includes Test Gate and Security Gate)
sdlc-flow.md         — phase sequence, ownership, sk.ff shortcut (12 phases including sk.test, sk.security-audit)
roles.md             — role definitions and command ownership

Test Gate (before story moves to security-review)
- Provider contract tests exist for every endpoint (backend-qa)
- Consumer contract tests exist for every consumed endpoint (frontend-qa)
- Every acceptance criterion has a mapped E2E test
- Coverage thresholds met: coding-standards.md Test Coverage Thresholds
- All tests pass — no skipped tests without documented reason

Security Gate (before story moves to done)
- security-audit.md exists for this story
- All OWASP Top 10 items documented as PASS/FAIL/NA
- No CRITICAL findings open
- HIGH findings acknowledged with tracking reference
- Secrets scan: CLEAN
- Verdict: CLEAR or CONDITIONAL (BLOCKED prevents done)
