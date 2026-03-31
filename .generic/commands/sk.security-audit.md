<!-- GENERIC LAYER — self-contained command -->
<!-- Before executing: read .generic/hooks/pre-command.md -->
<!-- After executing: read .generic/hooks/post-command.md -->
<!-- Context to load: see .generic/context-maps/command-context-map.md -->

# sk.security-audit
Security audit of implementation for active story.
Role: security | Level: story

## Pre-flight
1. Read session.yaml active_story_id and role
   NULL story → STOP: run sk.session focus --story {id} first
   role != security → STOP:
     "sk.security-audit requires security role.
      Run sk.session switch --role security"
2. Read story-{ID}.md — determine audit scope (services, endpoints, components)
3. Load context:
   - src/{service}/** (implementation files for active unit)
   - specs/intents/{intent}/units/{unit}/contracts/api-spec.json
   - .specify/memory/architecture-decisions.md (auth ADR)
   - .specify/memory/standards/coding-standards.md

## Mode detection
- security-audit.md exists for story → [REFINE MODE] update findings
- security-audit.md missing → [CREATE MODE]
Declare mode at start of execution.

## Step 1 — Determine audit scope
List all files in scope: services, API routes, middleware, auth code,
data access layers, frontend entry points handling user data.

## Step 2 — OWASP Top 10 evaluation
Evaluate each category. Record PASS / FAIL / NA with evidence:

| Category | Evaluation focus |
|----------|-----------------|
| A01 Broken Access Control | Authorization checks on every protected endpoint; IDOR vectors; path traversal |
| A02 Cryptographic Failures | Sensitive data in transit/at rest; weak algorithms; plaintext secrets |
| A03 Injection | SQL injection; command injection; template injection; input validation |
| A04 Insecure Design | Missing rate limiting; no abuse-case mitigations; insecure defaults |
| A05 Security Misconfiguration | Debug mode in prod; default credentials; unnecessary features enabled |
| A06 Vulnerable Components | Outdated dependencies; known CVEs in package list |
| A07 Auth Failures | Session fixation; weak token handling; missing MFA for sensitive ops |
| A08 Integrity Failures | Unsigned updates; unsafe deserialization; missing integrity checks |
| A09 Logging Failures | Sensitive data logged; insufficient audit trail; log injection |
| A10 SSRF | Unvalidated URLs in server-side requests; internal network exposure |

## Step 3 — Auth boundary check
Compare implementation auth middleware against auth ADR in
architecture-decisions.md. Flag any endpoint missing required auth.

## Step 4 — Secrets scan
Search codebase for: API keys, passwords, tokens, connection strings,
private keys hardcoded in source or config files.
Report tool used and result: CLEAN | FINDINGS.

## Step 5 — Dependency scan
Review package.json / requirements.txt / go.mod / pom.xml.
Report tool used, critical CVEs found, high CVEs found.

## Step 6 — API input validation review
For each endpoint in api-spec.json: verify input validation covers
required fields, type constraints, length limits, format patterns.

## Step 7 — Logging review
Check that logs do not contain: passwords, tokens, PII, credit card numbers.
Verify audit events are logged for: auth failures, permission denials,
sensitive data access.

## Step 8 — Write security-audit.md
Use template: .your-layer/templates/security-audit-template.md
(or .generic equivalent if available)
Output: specs/intents/{intent}/units/{unit}/stories/{story-id}/security-audit.md

Verdict rules:
- BLOCKED: any CRITICAL finding open
- CONDITIONAL: no CRITICAL, but HIGH findings present (must be tracked)
- CLEAR: no CRITICAL or HIGH findings

## Step 9 — Update story frontmatter
Update story-{ID}.md:
  security-status: CLEAR | CONDITIONAL | BLOCKED
  status: security-review (if not already done)

## Step 8b — STRIDE threat modeling
For each service/component in scope, evaluate:

| Threat | Evaluation focus |
|--------|-----------------|
| **S**poofing | Can an attacker impersonate a legitimate user or service? Auth mechanism sufficient? |
| **T**ampering | Can data be modified in transit or at rest without detection? Integrity checks present? |
| **R**epudiation | Can a user deny performing an action? Are audit logs sufficient and tamper-evident? |
| **I**nformation Disclosure | Can sensitive data be exposed to unauthorized parties? Over-broad error messages? |
| **D**enial of Service | Can the service be made unavailable? Rate limiting and resource limits in place? |
| **E**levation of Privilege | Can a user gain permissions beyond what is authorized? Privilege escalation vectors? |

Record each: PASS / FAIL / NA with evidence.
Severity: CRITICAL | HIGH | MEDIUM | LOW (same scale as OWASP findings).
Append STRIDE table to security-audit.md after OWASP table.
STRIDE CRITICAL findings block story progression (same rule as OWASP CRITICAL).

## Quality Bar
- All OWASP Top 10 items documented as PASS/FAIL/NA
- STRIDE table present with all 6 threat categories evaluated
- Every CRITICAL and HIGH finding (OWASP + STRIDE) has file + line reference
- Remediation guidance specific not generic
- Dependencies section lists tool used for scan
- Overall verdict: CLEAR | CONDITIONAL | BLOCKED
  BLOCKED → story cannot proceed to review (any CRITICAL finding — OWASP or STRIDE)
  CONDITIONAL → HIGH findings acknowledged, proceed with tracking
  CLEAR → no critical or high findings
