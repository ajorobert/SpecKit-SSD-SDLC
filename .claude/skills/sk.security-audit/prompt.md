# sk.security-audit
Security audit of implementation for active story.
Role: security | Level: story

## Pre-flight & Input Artifacts
Resolve the active story via `.specify/memory/standards/story-lifecycle.md` §3 (`unit_dir`).
No active story → STOP: run sk.session/sk.story first.

- `UNIT_DIR/stories/` (story.md, requirement.md) — audit scope + security NFRs
- `UNIT_DIR/02-design/api-contract.md` (+ api-spec.json) — attack surface
- `UNIT_DIR/04-implementation/{ProjectName}/implementation.md` — files changed (scopes the scan)
- impacted projects' `code-root` from `.specify/memory/projects/index.md` → `src/**` to scan
- `.specify/memory/architecture-decisions.md` — auth ADR + security decisions
  (Backward compat: legacy `specs/intents/**` artifacts read in place if present.)

## Output Artifacts (per story-lifecycle.md §2)
Write four files under `UNIT_DIR/07-security-audit/` (create if absent, update in place per §7):
`owasp-report.md`, `stride-review.md`, `dependency-scan.md`, `security-signoff.md`.

## Steps
1. Determine audit scope from the active story and impacted projects.
2. **`owasp-report.md`** — evaluate each OWASP Top 10 category against the implementation
   (PASS/FAIL/NA + evidence + severity). Check auth boundaries against the auth ADR; check API
   input validation; review logging for sensitive-data exposure.
3. **`stride-review.md`** — STRIDE threat model (table below).
4. **`dependency-scan.md`** — scan dependencies: vulnerable packages, outdated libraries, and
   container image vulnerabilities. List the tool(s) used and every finding with severity + fix.
5. **`security-signoff.md`** — final approval record before release (verdict + sign-off).

### STRIDE threat modeling (`stride-review.md`)
For each service/component in scope, evaluate:

| Threat | Evaluation focus |
|--------|-----------------|
| **S**poofing | Can an attacker impersonate a legitimate user or service? Auth mechanism sufficient? |
| **T**ampering | Can data be modified in transit or at rest without detection? Integrity checks present? |
| **R**epudiation | Can a user deny performing an action? Are audit logs sufficient and tamper-evident? |
| **I**nformation Disclosure | Can sensitive data be exposed to unauthorized parties? Over-broad error messages? |
| **D**enial of Service | Can the service be made unavailable? Rate limiting and resource limits in place? |
| **E**levation of Privilege | Can a user gain permissions beyond what is authorized? Privilege escalation vectors? |

Record each: PASS / FAIL / NA with evidence. Severity: CRITICAL | HIGH | MEDIUM | LOW (same
scale as OWASP). STRIDE CRITICAL findings block story progression (same rule as OWASP CRITICAL).

### Sign-off (`security-signoff.md`)
```
# {STORY-ID} — Security Sign-off
Overall Verdict: CLEAR | CONDITIONAL | BLOCKED
OWASP: {n PASS / n FAIL / n NA}   STRIDE: {…}   Dependencies: {n findings}
Unresolved CRITICAL: {count}   HIGH: {count}
Approval before release: GRANTED | WITHHELD
Approver / Date: {…}
```

## Quality Bar
- `owasp-report.md`: all OWASP Top 10 items documented as PASS/FAIL/NA
- `stride-review.md`: all 6 threat categories evaluated
- `dependency-scan.md`: vulnerable packages, outdated libs, container vulns covered; tool named
- Every CRITICAL and HIGH finding (OWASP + STRIDE + dependency) has a file/package reference
- Remediation guidance specific not generic
- `security-signoff.md` present with the overall verdict: CLEAR | CONDITIONAL | BLOCKED
  BLOCKED → story cannot proceed to release (any unresolved CRITICAL — OWASP, STRIDE, or dependency)
  CONDITIONAL → HIGH findings acknowledged, proceed with tracking
  CLEAR → no critical or high findings
