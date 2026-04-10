# sk.init — Project Initialization

Initialize or update a project's SpecKit memory layer.

## Mode Detection

Check whether `.specify/project-config.md` exists:
- **Missing** → [NEW PROJECT] Full interview + generate all memory files + scaffold
- **Exists** → [UPDATE] Show current values, selective re-generation menu

---

## [NEW PROJECT] Steps

### Step 1 — Interview

Ask the following questions in a natural conversation (not a form). Gather enough detail to write complete, specific files — not generic placeholders.

**1. Project Vision**
- What is the name of this project?
- What does this system do in 1–2 sentences?
- Who are the primary users or actors?

**2. Services and Apps**
- What services or applications make up this system?
  (e.g. REST API, web frontend, mobile app, background workers, admin panel)
- For each service: what is its primary responsibility?

**3. Tech Stack**
- Backend: language, framework, version?
- Frontend: framework, version?
- Mobile (if any): platform, framework?
- Databases: which DB for what purpose?
- Infrastructure: cloud provider, container runtime, CI/CD?
- Any third-party services or APIs?

**4. Auth and Integrations**
- How does authentication work? (e.g. JWT, OAuth2, session cookies, API keys)
- Any external APIs, payment providers, notification services?

**5. Architecture and Design Principles**
The following are ON by default. Only ask if the user gives a conflicting signal:
- **Clean Architecture** — strict layering (domain → application → infrastructure). No infrastructure dependencies in domain layer.
- **DDD** — bounded contexts, aggregates, domain events. No cross-context direct DB access.
- **Structured JSON logging** — all log entries include trace_id, span_id, service, level, timestamp.
- **Distributed tracing** — W3C traceparent propagated on all inbound/outbound HTTP calls and async messages.
- **RED metrics** — rate, errors, duration instrumented on every service endpoint.

Ask only:
- Do any of these conflict with your constraints or existing stack? (If no answer: all defaults apply.)
- CQRS or event-sourcing in addition to the above? (Default: no.)
- Microservices or modular monolith? (Default: derive from step 2 service count.)

**6. Error Handling**
Default: structured error responses (Problem Details RFC 7807 shape), logged at WARN for client errors and ERROR for unexpected failures. Never swallow silently.
Ask only:
- Which error handling pattern for the language? (e.g. Result<T,E> | typed exceptions | Go errors.Wrap)
  If no answer: infer from tech stack chosen in step 3.
- Any special handling for unexpected errors beyond ERROR log + 500 response?

**7. Observability Tooling**
The *format and behaviour* (structured JSON, W3C traceparent, RED metrics) are non-negotiable defaults.
Ask only which *sinks* to use — and "not decided yet" is a valid answer:
- Logging sink: (e.g. Serilog, Zap, Winston — or "framework default")
- Tracing backend: (e.g. OpenTelemetry → Jaeger/Datadog/X-Ray — or "not decided yet")
- Metrics sink: (e.g. Prometheus, Datadog, CloudWatch — or "not decided yet")
  "Not decided yet" is recorded explicitly and flagged by sk.verify until resolved.

**8. Principles and Constraints**
- What constraints are absolutely fixed — technology mandates, compliance requirements,
  deployment restrictions, or organizational policies that cannot be changed?
- Where and how will this system run?
  (e.g., on-premise, cloud provider, containerized, serverless, hybrid)

**9. Team Conventions**
- Any mandatory coding rules, naming conventions, or standards to enforce?
- Any specific patterns the team always uses? (e.g. Result<T,E> errors, repository pattern)
- Anything the AI should always or never do in this codebase?

**10. Overrides (optional)**
- Any framework defaults to override?
  (e.g. skip ADR for internal tools, allow sk.implement without sk.plan for hotfixes)

### Step 2 — Generate Output Artifacts

Using the interview answers, write the following files with complete, specific content.
Do not leave any placeholders — if something wasn't mentioned, make a reasonable inference and note it.

**`.specify/project-config.md`**
- Identity: name, description (1–2 sentences), stack summary
- Custom Rules: all rules mentioned in step 5
- Overrides: all overrides mentioned in step 6

**`.specify/memory/system-context.md`**
- System Type: derived from services
- Services: list from step 2
- Frontend Surfaces: list from step 2
- External Dependencies: from step 4
- Current Development Focus: "Initial development"

**`.specify/memory/service-registry.md`**
- One entry per service from step 2
- For each: name, responsibility, tech, exposed API type (REST/GraphQL/gRPC/none)

**`.specify/memory/standards/tech-stack.md`**
- Backend: specific framework + version
- Databases: each DB with its purpose
- Frontend Surfaces: each surface with its framework
- Infrastructure: cloud, containers, CI/CD
- Observability Tooling: logging library, tracing backend, metrics sink (from step 7)
- Constraints: any noted constraints

**`.specify/memory/standards/coding-standards.md`**
- Fill in Formatter/Linter with the stack's standard tools (from step 9)
- Fill in Error Handling Pattern with the choice from step 6
  (replace the `[Fill in]` placeholder — e.g. "TypeScript: Result<T,E> using neverthrow")
- Add any team conventions from steps 5/9 as Implementation Rules
- Keep the pre-existing [REQUIRED] module boundary and domain logic rules intact

**`.specify/memory/standards/api-standards.md`**
- Fill in URL Structure, Versioning, Response Envelope, Error Format from conventions in step 3/5
- Keep the pre-existing Pagination and Idempotency rules intact

**`.specify/memory/standards/data-standards.md`**
- Fill in Naming Conventions from stack conventions (e.g. snake_case for PostgreSQL)
- Required Fields: id, created_at, updated_at minimum
- Keep the pre-existing Index Strategy, Partitioning, Transaction rules intact

**`.specify/memory/constitution.md`**
Using answers from steps 5, 6, 7, 8 (Principles, Error Handling, Observability, Constraints), write:
```
# Project Constitution
Version: 1.0.0 | Ratification: {today} | Last Amended: {today}

## System Identity
{name} — {purpose from step 1}

## Primary Actors
{actors from step 1}

## Architecture Principles
DEFAULT (active unless explicitly overridden in step 5):
 - Clean Architecture: domain layer MUST have zero infrastructure dependencies
 - DDD: each bounded context owns its aggregate; cross-context access via contracts only
 - No business logic in controllers; no direct DB queries outside repositories
 - One aggregate modified per command; cross-aggregate changes via domain events
{If user overrode any default in step 5: replace or append the override here}

## Error Handling Contract
DEFAULT shape (override pattern from step 6 if given):
 - Client errors (4xx): structured Problem Detail response; logged at WARN
 - Unexpected errors (5xx): structured Problem Detail response; logged at ERROR with full context; never expose internal details to caller
 - Silent swallowing: NEVER permitted
 Error pattern: {inferred from tech stack in step 3, or explicit answer from step 6}

## Observability Contract
DEFAULT behaviour (non-negotiable regardless of tooling):
 - Structured JSON logging on all services: timestamp, level, service, trace_id, span_id, message
 - W3C traceparent propagated: inbound HTTP extract; outbound HTTP inject; async payloads embed trace_id
 - RED metrics on every endpoint: http_requests_total, http_errors_total, http_request_duration_seconds
 - GET /health on every service: 200 ok / 503 degraded
Tooling (from step 7; "not decided yet" if not provided):
 - Logging sink: {answer or "framework default"}
 - Tracing backend: {answer or "not decided yet — flagged for resolution"}
 - Metrics sink: {answer or "not decided yet — flagged for resolution"}

## Non-Negotiable Constraints
{numbered list from step 8 — each item declarative and testable, no vague language}

## Deployment Context
{paragraph from steps 3 and 8}

## Governance
Amendment procedure: re-run sk.init [8] to update constitution.
Compliance review: sk.verify checks constitution constraints at each quality gate.
```
All sections must be declarative and testable. Replace vague adjectives with measurable criteria.
"Not decided" is acceptable only in Observability Contract — flag it; all others must have a decision.

### Step 3 — Scaffold (if not exists)

Create these only if they don't already exist:
- `specs/knowledge-base.md` — pre-fill Why This System Exists and Core Actors from interview
- `history/adr/` — empty directory (create `.gitkeep` if needed)
- `history/prompts/` — empty directory (create `.gitkeep` if needed)

### Step 4 — Confirm

Report what was created:
```
✓ .specify/project-config.md
✓ .specify/memory/system-context.md
✓ .specify/memory/service-registry.md
✓ .specify/memory/constitution.md
✓ .specify/memory/standards/tech-stack.md
✓ .specify/memory/standards/coding-standards.md
✓ .specify/memory/standards/api-standards.md
✓ .specify/memory/standards/data-standards.md
✓ specs/knowledge-base.md

Next: run /sk.session start to set your role, then /sk.specify to begin your first intent.
```

---

## [UPDATE] Steps

### Step 1 — Load Current Values

Read the existing files silently to understand current state.

### Step 2 — Present Menu

```
Project: [name from project-config.md]

What would you like to update?
  [1] project-config     — identity + custom rules + overrides
  [2] system-context     — system overview, services, external dependencies
  [3] tech-stack         — backend, databases, frontend, infrastructure
  [4] coding-standards   — formatter, implementation rules, error handling
  [5] api-standards      — URL structure, versioning, response envelope
  [6] data-standards     — naming, required fields, migration rules
  [7] service-registry   — service list and boundaries
  [8] constitution       — architecture principles, error handling contract, observability contract, constraints
  [9] all memory files   — re-run full interview for everything

Enter numbers (comma-separated) or press Enter to cancel:
```

### Step 3 — Re-interview and Regenerate

For each selected item:
- Show the current value
- Ask what should change
- Regenerate only that file with the updated content

---

## Input Artifacts
- `.specify/project-config.md` (UPDATE mode only)
- `.specify/memory/*.md` (UPDATE mode only — to show current values)

## Output Artifacts
- `.specify/project-config.md`
- `.specify/memory/system-context.md`
- `.specify/memory/service-registry.md`
- `.specify/memory/constitution.md`
- `.specify/memory/standards/tech-stack.md`
- `.specify/memory/standards/coding-standards.md`
- `.specify/memory/standards/api-standards.md`
- `.specify/memory/standards/data-standards.md`
- `specs/knowledge-base.md` (NEW PROJECT only, if absent)

## Quality Bar
- No `<!-- TODO -->` or placeholder lines remain in generated files
- `system-context.md`: all sections filled — no empty fields
- `tech-stack.md`: specific versions or ranges, not just "React" or "Node"
- `coding-standards.md`: actionable rules enforceable by code review, not generic advice
- `api-standards.md`: URL structure and response envelope are concrete, not aspirational
- `project-config.md`: Custom Rules section has at least one entry, or explicitly states "None"
- `constitution.md`: Architecture Principles, Error Handling Contract, and Observability Contract all populated — no [PLACEHOLDER] tokens; "Not decided" only allowed in Observability Contract
- `coding-standards.md`: Formatter/Linter and Error Handling Pattern `[Fill in]` placeholders replaced with actual project values
