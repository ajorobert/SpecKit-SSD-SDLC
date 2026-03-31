Governance Skill
Loaded by: sk.verify, sk.ff, sk.impact
Files

checkpoint-rules.md  — complexity classification, checkpoint behaviour
quality-gates.md     — PASS/FAIL gate definitions per phase (includes Test Gate and Security Gate)
sdlc-flow.md         — phase sequence, ownership, sk.ff shortcut
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
- STRIDE table present with all 6 threat categories evaluated
- No CRITICAL findings open (OWASP or STRIDE)
- HIGH findings acknowledged with tracking reference
- Secrets scan: CLEAN
- Verdict: CLEAR or CONDITIONAL (BLOCKED prevents done)

## Execution Phase Handoffs (gstack wrappers)
These commands wrap gstack execution tools with spec context injection.
They run AFTER the spec/architecture phases and BEFORE/AFTER sk.verify.

sk.plan-eng-review  → runs after sk.architecture; architect validates plan against
                       service-registry + ADRs before implementation begins
sk.review           → runs after sk.implement; injects bounded-context + contracts
                       + ADRs into gstack /review; violations block sk.verify
sk.investigate      → runs if story is blocked during or after sk.implement;
                       classifies findings as implementation bug vs spec deviation
sk.qa               → runs after sk.test (frontend-qa only); browser acceptance
                       testing mapped to acceptance criteria
sk.ship             → runs after sk.verify PASS + security-audit CLEAR/CONDITIONAL;
                       hard blocks enforce quality gate before gstack /ship invoked

Prerequisite: gstack must be installed at ~/.claude/skills/gstack
Installation: see github.com/garrytan/gstack
