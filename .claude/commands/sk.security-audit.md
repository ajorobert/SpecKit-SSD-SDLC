# sk.security-audit
Security audit of implementation for active story.
Role: security | Level: story

## Input Artifacts
specs/intents/{intent}/units/{unit}/knowledge-base.md
  (external constraints + invariants inform audit scope)

src/{service}/** (implementation files for active unit)
specs/intents/{intent}/units/{unit}/contracts/api-spec.json
.specify/memory/architecture-decisions.md
story-{ID}.md (audit scope)

## Steps
1. Verify role = security
   NOT security → STOP: "sk.security-audit requires security role.
   Run sk.session switch --role security"
2. Determine audit scope from active story and unit
3. Evaluate each OWASP Top 10 category against implementation
4. Check auth boundaries against architecture-decisions.md auth ADR
5. Scan for secrets and hardcoded credentials
6. Review dependency list for known CVEs
7. Check API inputs for validation coverage
8. Review logging for sensitive data exposure
9. Write audit report using security-audit-template.md

## Output Artifacts
specs/intents/{intent}/units/{unit}/stories/{story-id}/security-audit.md

## Quality Bar
- All OWASP Top 10 items documented as PASS/FAIL/NA
- Every CRITICAL and HIGH finding has file + line reference
- Remediation guidance specific not generic
- Dependencies section lists tool used for scan
- Overall verdict: CLEAR | CONDITIONAL | BLOCKED
  BLOCKED → story cannot proceed to review
  CONDITIONAL → HIGH findings acknowledged, proceed with tracking
  CLEAR → no critical or high findings
