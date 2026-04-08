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

**5. Principles and Constraints**
- What constraints are absolutely fixed — technology mandates, compliance requirements,
  deployment restrictions, or organizational policies that cannot be changed?
- What is the team's primary engineering philosophy?
  (e.g., simplicity-first, event-driven, API-first, CQRS, DDD, microservices)
- Where and how will this system run?
  (e.g., on-premise, cloud provider, containerized, serverless, hybrid)

**6. Team Conventions**
- Any mandatory coding rules, naming conventions, or standards to enforce?
- Any specific patterns the team always uses? (e.g. Result<T,E> errors, repository pattern)
- Anything the AI should always or never do in this codebase?

**7. Overrides (optional)**
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
- Constraints: any noted constraints

**`.specify/memory/standards/coding-standards.md`**
- Fill in Formatter/Linter with the stack's standard tools
- Add any team conventions from step 5 as Implementation Rules
- Keep the pre-existing [REQUIRED] module boundary rules intact

**`.specify/memory/standards/api-standards.md`**
- Fill in URL Structure, Versioning, Response Envelope, Error Format from conventions in step 3/5
- Keep the pre-existing Pagination and Idempotency rules intact

**`.specify/memory/standards/data-standards.md`**
- Fill in Naming Conventions from stack conventions (e.g. snake_case for PostgreSQL)
- Required Fields: id, created_at, updated_at minimum
- Keep the pre-existing Index Strategy, Partitioning, Transaction rules intact

**`.specify/memory/constitution.md`**
Using answers from step 5 (Principles and Constraints), write:
```
# Project Constitution
Version: 1.0.0 | Ratification: {today} | Last Amended: {today}

## System Identity
{name} — {purpose from step 1}

## Primary Actors
{actors from step 1}

## Non-Negotiable Constraints
{numbered list from step 5 — each item declarative and testable, no vague language}

## Tech Philosophy
{paragraph from step 5 — replace "should" with MUST or MAY}

## Deployment Context
{paragraph from steps 3 and 5}

## Governance
Amendment procedure: re-run sk.init [8] to update constitution.
Compliance review: sk.verify checks constitution constraints at each quality gate.
```
Principles must be declarative and testable. Replace vague adjectives with measurable criteria.

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
  [8] constitution       — principles, constraints, tech philosophy, deployment context
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
- `constitution.md`: all principles declarative and testable — no vague adjectives, no [PLACEHOLDER] tokens
