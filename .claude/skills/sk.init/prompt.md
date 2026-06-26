# sk.init — Project & Workspace Initialization

Initialize or update a project's SpecKit memory layer, or an enterprise
workspace that governs multiple projects.

## Mode Detection

Resolve the mode in this order (first match wins). The single-project
[NEW PROJECT] and [UPDATE] flows are unchanged — workspace detection is
layered on top and never alters them.

1. `.specify/memory/projects/index.md` exists
   → **[WORKSPACE UPDATE]** Enterprise workspace already initialized.
     Show the project router + per-project update menu.
2. Else, `.specify/project-config.md` exists
   → **[UPDATE]** Single-project flow. Show current values, selective
     re-generation menu. (unchanged)
3. Else (neither exists) → ask one routing question first:

   > "Are you initializing a **single project** or an **enterprise
   > workspace** that contains multiple projects?"

   - **Single project** → **[NEW PROJECT]** Full interview + generate all
     memory files + scaffold. (unchanged)
   - **Enterprise workspace** → **[WORKSPACE INIT]** Workspace interview +
     generate workspace memory + per-project memory. (new — see below)

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
- **Frontend surfaces** — NEW PROJECT only. Do NOT run this block in UPDATE mode. In UPDATE mode, show the current tech-stack.md value and ask only "What would you like to change?"
  For each frontend surface identified in step 2:
  1. Ask: "What is the primary use case for this surface?" (e.g. marketing site, customer portal, admin dashboard, mobile app, prototype/personal tool)
  2. Based on their answer, recommend a framework using this decision guide:

  | Use Case | Recommended Framework | Key Reason |
  |---|---|---|
  | SEO-critical marketing site or content portal (React preference) | **Next.js (App Router)** | SSR + SSG + ISR, built-in SEO metadata API |
  | SEO-critical marketing site or content portal (Vue preference) | **Nuxt 3** | SSR + SSG with Vue syntax, file-based routing |
  | Customer portal with auth, forms, dynamic pages (React) | **Next.js (App Router) + NextAuth v5** | SSR + server actions + auth integration |
  | Customer portal with auth, forms, dynamic pages (Vue) | **Nuxt 3 + nuxt-auth-utils** | SSR + Vue composition API + auth module |
  | Admin dashboard / internal tool / data tables (React) | **React + Vite + TanStack Router** | SPA simplicity, no SSR overhead, fast dev |
  | Admin dashboard / internal tool / data tables (Vue) | **Vue 3 + Vite + Vue Router** | Lightweight SPA, easy learning curve |
  | Enterprise app — large team, strict conventions, strong typing | **Angular 17+ (standalone components)** | Opinionated full framework: DI, routing, forms, state built-in |
  | Simple personal tool or prototype | **Next.js (minimal)** or **Vanilla JS** | Low ceremony; Next.js if you want structure |
  | iOS + Android mobile app | **React Native + Expo** | Managed workflow, cross-platform |
  | Embedded widget or micro-frontend | **Vanilla JS + Web Components** | Minimal footprint, framework-agnostic |

  3. Say: "Based on your use case, I recommend **[X]** because [one-sentence reason]. Would you like to go with that, or do you have a different preference?"
  4. Once the framework is confirmed, immediately ask: **"Do you want to write the code in TypeScript or plain JavaScript?"**
     Use this to guide the answer:

     | Framework chosen | Recommendation | Reason |
     |---|---|---|
     | Angular 17+ | **TypeScript (strict)** — effectively mandatory | Angular's DI, decorators, and tooling are built for TS; plain JS is unsupported in practice |
     | Next.js (App Router) | **TypeScript (strict)** — strongly recommended | App Router types (PageProps, generateMetadata, Server Actions) require TS for correctness |
     | Nuxt 3 | **TypeScript (strict)** — strongly recommended | auto-imports and composables are fully typed; JS loses most of Nuxt's DX benefits |
     | React + Vite | **TypeScript** — recommended, JS acceptable | TS catches prop mismatches early; plain JS is fine for small/prototype projects |
     | Vue 3 + Vite | **TypeScript** — recommended, JS acceptable | Composition API with `<script setup lang="ts">` is the modern default |
     | Vanilla JS | **Plain JS** — default; JSDoc optional | No build step required; JSDoc + VS Code gives lightweight type hints if desired |

     If TypeScript is chosen: ask "Strict mode or standard?"
     — Default recommendation: **strict** for all frameworks above.
     — Record as `TypeScript (strict)` or `TypeScript (standard)` or `JavaScript` in tech-stack.md.

  5. Record the chosen framework **and version**, and the language choice in tech-stack.md — never leave either as "TBD".

- Mobile (if any): platform, framework?
- Databases: which DB for what purpose?
- Infrastructure: cloud provider, container runtime, CI/CD?
- Any third-party services or APIs?

**3b. UI & Design Direction** (NEW PROJECT only. Only ask when a frontend surface was identified in step 2. Skip entirely for backend-only projects.)

Capture only project-wide **invariants** here — the high-level direction every surface inherits. The detailed, per-surface decisions (component library, full design-aesthetic catalogue, type-specific style combinations) are made at design time by `/sk.design`, which reads the catalogue in `.claude/skills/frontend-design-system/design-styles.md`. Keep this section short.

- **Figma / Design file:**
  Ask: "Do you have a Figma file, design mockup, or style guide?"
  - **Yes** → record the URL/path in `project-config.md` under `## Design References`, and whether it needs a login. `/sk.design` and `/sk.implement` read this to extract colours, spacing, and component shapes.
  - **No** → record `Design References: None`.

- **Primary brand colour:**
  Ask: "What is your primary brand colour?" (hex, name, or "not decided")
  - Record under `## Design References` in `project-config.md`. If given, note it maps to `--primary` in the token system; if "not decided", it defaults to the component library's theme.

- **Dark mode:**
  Ask: "Does this project need dark mode?" (yes / no / not decided)
  - `required` → `frontend-design-system` enforces the `.dark` class strategy. `light-only` → skip dark token variants. `not decided` → flagged by `sk.verify` until resolved. Record in `project-config.md`.

- **Overall visual direction (one line, optional):**
  Ask: "In a sentence, what overall visual direction do you want?" (e.g. "clean and minimal", "bold and playful", "dark and technical", or "let the design phase decide").
  Record verbatim in `project-config.md` under a `Design Direction` field. This is a seed, not the final aesthetic — `/sk.design` expands it per surface against the design-styles catalogue and records the concrete style there.

  Do NOT present the full design-style catalogue or component-library options here — that happens in `/sk.design`.

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
- **CQRS pattern** — XxxCommand/XxxQuery + dedicated handler per use case. Default ON.
  Exception: pure infrastructure stories (no application use case — e.g. DBX plumbing) — pattern does not apply there.
  Ask only: do you want command bus / dispatcher infrastructure (e.g. MediatR, custom mediator)?
  (Default: no. Handlers are called directly from controllers/endpoints.)
- **Command Handler Idempotency** — when CQRS is ON, every command handler must be safe to replay with the same input without re-executing side effects. Default ON. Record in constitution.
  Ask only: Is command dispatch async (message queue, event bus, background worker)?
  - Yes → messaging_context = true. Handler idempotency REQUIRED; outbox pattern REQUIRED for any event published inside a command handler.
  - No (direct call) → messaging_context = false. commandId-based deduplication is the default pattern.
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
{If messaging_context = true:}
 - Command Handler Idempotency: REQUIRED — every command carries commandId (UUID v4); handler checks commandId against dedup store before executing; duplicate → return cached result; log WARN + increment commands_duplicate_total
 - Transactional Outbox: REQUIRED — events published inside command handlers must be written to outbox table in same transaction as state change; relay process publishes from outbox; no dual-write
{If messaging_context = false:}
 - Command Handler Idempotency: REQUIRED — every command carries commandId (UUID v4); same commandId must produce same result without re-executing side effects
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
- `specs/guide.yaml` — empty system-level guide, generated from `templates/artifacts/guide-template.yaml` (Tier 1 structure)
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
✓ specs/guide.yaml
✓ specs/knowledge-base.md

Next: run /sk.session start to set your role, then /sk.specify to begin your first intent.
```

---

## [UPDATE] Steps

### Step 1 — Load Current Values

Read the existing files silently to understand current state.

**Design Direction Detection (UPDATE mode — frontend projects only):**
The concrete design aesthetic is owned by `/sk.design` (recorded per surface in its design artifacts); `project-config.md` holds only the high-level `Design Direction` seed.
- **`Design Direction` present in project-config.md** → record internally; do NOT re-ask.
- **Absent** → if the session involves frontend work, prompt once: "No design direction is recorded. Want to add a one-line direction now? (y/n)" If yes → ask the one-line question from the NEW PROJECT section 3b. If no → skip; `/sk.design` will establish it.
- **Key rule (consistency):** When adding UI to an existing project, agents MUST follow the established aesthetic — read the design style recorded by `/sk.design` for that surface (and the `Design Direction` seed in `project-config.md`). They must NOT introduce a different visual style unless the user explicitly asks to change it.

### Step 2 — Present Menu

```
Project: [name from project-config.md]

What would you like to update?
  [1] project-config     — identity + custom rules + overrides (includes Design Direction)
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

## [WORKSPACE INIT] Steps

Enterprise mode. Initializes a workspace that governs multiple projects.
This flow is independent of the single-project flows above — it does NOT
generate or require `.specify/project-config.md`. Each project gets its own
isolated memory folder under `.specify/memory/projects/{name}/`.

### Step W1 — Workspace Interview

Ask these in order. Keep it a tight, structured conversation.

**1. Workspace identity**
- What is the **workspace name**?
- What is the **total number of projects** in this workspace? → `totalProjects`

**2. Project mix**
- How many **backend** projects? → `backendCount`
- How many **frontend** projects? → `frontendCount`
- How many **mobile** projects? → `mobileCount`

**Validation (hard gate):**
```
backendCount + frontendCount + mobileCount == totalProjects
```
If the sum does NOT equal `totalProjects`, do not proceed. Report the
mismatch (e.g. "You said 5 total but the breakdown sums to 4") and re-ask
the four counts until the equation holds.

**3. Per-project details**
Loop over every project (group the loop by type so the user fills all
backend projects, then all frontend, then all mobile). For each project
collect:
- **Project name** (used as the folder slug under `projects/`)
- **Project type** — one of: `Backend` | `Frontend` | `Mobile`
  (pre-assigned by which group is being filled; confirm only)
- **Code root path** — absolute or workspace-relative path to the code
- **Technology stack** — language + primary framework/libraries
- **Framework version** — concrete version or range (never "TBD")
- **Architecture pattern** — e.g. Clean Architecture, MVC, Feature-Sliced,
  Modular Monolith, MVVM
- **Coding standards** — formatter/linter + key conventions to enforce

### Step W2 — Generate Workspace Memory

Create the directory `.specify/memory/` if it does not exist.

**`.specify/memory/projects/index.md`** — the workspace router.
Write the workspace name as the heading, then a router table with one row
per project:
```
# {Workspace Name} — Project Router

Workspace memory index. Each project owns an isolated memory folder under
`projects/{name}/`. Read the relevant project folder before working in it.

Total projects: {totalProjects}  (Backend: {backendCount} · Frontend: {frontendCount} · Mobile: {mobileCount})

| Project | Type | Code Root |
|---|---|---|
| [{name}](./{name}/project.md) | {type} | `{code root path}` |
| ... | ... | ... |
```

### Step W3 — Generate Per-Project Memory

For each project, create `.specify/memory/projects/{name}/` and write:

**`projects/{name}/project.md`**
```
# {Project Name}

| Field | Value |
|---|---|
| Workspace | {Workspace Name} |
| Type | {Backend \| Frontend \| Mobile} |
| Code Root | `{code root path}` |
| Architecture Pattern | {architecture pattern} |

## Responsibility
{1–2 sentence inference of what this project does, from its name + type +
stack. If the user gave a description, use it verbatim.}

## Memory Files
- [tech-stack.md](./tech-stack.md) — technology + framework version
- [coding-standards.md](./coding-standards.md) — conventions to enforce

## Notes
{any extra context the user gave; otherwise "None"}
```

**`projects/{name}/tech-stack.md`**
```
# {Project Name} — Tech Stack

| Field | Value |
|---|---|
| Type | {Backend \| Frontend \| Mobile} |
| Technology Stack | {technology stack} |
| Framework Version | {framework version} |
| Architecture Pattern | {architecture pattern} |

## Stack Detail
{expand the stack into specifics: language, framework, key libraries,
data layer, and — for backend — API style; for frontend/mobile — UI layer.
Make reasonable inferences; never leave "TBD".}
```

**`projects/{name}/coding-standards.md`**
```
# {Project Name} — Coding Standards

## Formatter / Linter
{from interview, or the stack's standard tooling, e.g. dotnet format +
EditorConfig, Prettier + ESLint, ktlint}

## Conventions
{the coding standards the user gave, as enforceable rules — one per line}

## Architecture Rules
- Architecture pattern: {architecture pattern} — layer/module boundaries
  MUST be respected.
{add pattern-appropriate boundary rules, e.g. for Clean Architecture:
"domain layer has zero infrastructure dependencies".}
```

### Step W3.5 — Generate Shared Workspace Standards

These are **workspace-wide** technical standards that all projects inherit
(complement, not replace, each project's own `coding-standards.md`). Create
`.specify/memory/standards/` and write the three files below.

Ask one short batch of questions first (defaults in brackets — accept
"use defaults" to skip):
- **API:** URL style + versioning + error format? [REST, `/v{n}` path versioning, RFC 7807 Problem Details]
- **Data:** naming convention + required audit fields? [snake_case, `id` + `created_at` + `updated_at`]
- **Observability:** logging / tracing / metrics sinks? ["not decided yet" is valid and gets flagged]

**`.specify/memory/standards/api-standards.md`**
```
# Workspace API Standards
Applies to all backend/BFF projects in the workspace.

## URL Structure
{e.g. /api/{resource}, plural nouns, kebab-case}

## Versioning
{e.g. path-based /v1, header-based, or none}

## Response Envelope
{concrete success + collection shape}

## Error Format
{RFC 7807 Problem Details by default — concrete fields}

## Pagination & Idempotency
- List endpoints paginate (cursor or page/limit) — state which.
- Mutating endpoints accept an idempotency key where applicable.
```

**`.specify/memory/standards/data-standards.md`**
```
# Workspace Data Standards
Applies to every project that owns persistent state.

## Naming Conventions
{e.g. snake_case tables/columns for PostgreSQL}

## Required Fields
- id (primary key)
- created_at
- updated_at
{plus any audit/tenant fields the user names}

## Index, Migration & Transaction Rules
- Every foreign key is indexed.
- Schema changes ship as forward-only migrations.
- One transaction per unit of work; no partial commits.
```

**`.specify/memory/standards/observability-standards.md`**
```
# Workspace Observability Standards
Non-negotiable behaviour across every project, regardless of tooling.

## Logging
- Structured JSON: timestamp, level, service, trace_id, span_id, message.

## Tracing
- W3C traceparent: inbound extract, outbound inject, async payloads embed trace_id.

## Metrics
- RED on every endpoint: requests_total, errors_total, request_duration_seconds.

## Health
- GET /health on every service: 200 ok / 503 degraded.

## Tooling
- Logging sink: {answer or "framework default"}
- Tracing backend: {answer or "not decided yet — flagged for resolution"}
- Metrics sink: {answer or "not decided yet — flagged for resolution"}
```

### Step W4 — Confirm

Report what was created, e.g.:
```
✓ .specify/memory/projects/index.md   (router — {totalProjects} projects)

For each project:
✓ .specify/memory/projects/{name}/project.md
✓ .specify/memory/projects/{name}/tech-stack.md
✓ .specify/memory/projects/{name}/coding-standards.md

Shared standards:
✓ .specify/memory/standards/api-standards.md
✓ .specify/memory/standards/data-standards.md
✓ .specify/memory/standards/observability-standards.md

Next: run /sk.init again to add or update a project, or open a project
folder under .specify/memory/projects/ to begin work.
```

---

## [WORKSPACE UPDATE] Steps

Triggered when `.specify/memory/projects/index.md` already exists.

### Step 1 — Load Router

Read `projects/index.md` silently to learn the workspace name, counts, and
the current project list.

### Step 2 — Present Menu

```
Workspace: [name from index.md]
Projects: [list each name — type]

What would you like to do?
  [1] Add a new project        — interview + new projects/{name}/ folder + router row
  [2] Update an existing project — pick one, regenerate its memory files
  [3] Update the router only     — fix names / types / code roots in index.md
  [4] Update shared standards    — api / data / observability standards

Enter a number or press Enter to cancel:
```

### Step 3 — Execute

- **[1] Add project** — run the Step W1 per-project questions for one
  project, write its three memory files (Steps W3), append a row to the
  router, and increment the relevant count + `totalProjects` in `index.md`.
  Re-validate the count equation after updating.
- **[2] Update project** — show that project's current memory values, ask
  what changes, regenerate only the affected file(s) in its folder. Update
  the router row if name/type/code-root changed.
- **[3] Update router** — edit only `index.md`.
- **[4] Update shared standards** — show current values from
  `standards/{api,data,observability}-standards.md`, ask what changes,
  regenerate only the affected file(s). If the `standards/` folder is
  absent (workspace predates this step), generate it via Step W3.5.

Never touch other projects' folders during an update — each project's
memory is isolated.

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
- `specs/guide.yaml` (NEW PROJECT only, if absent)
- `specs/knowledge-base.md` (NEW PROJECT only, if absent)

### Workspace (WORKSPACE INIT / WORKSPACE UPDATE only)
- `.specify/memory/projects/index.md` (router)
- `.specify/memory/projects/{name}/project.md` (one per project)
- `.specify/memory/projects/{name}/tech-stack.md` (one per project)
- `.specify/memory/projects/{name}/coding-standards.md` (one per project)
- `.specify/memory/standards/api-standards.md` (shared)
- `.specify/memory/standards/data-standards.md` (shared)
- `.specify/memory/standards/observability-standards.md` (shared)

## Quality Bar
- No `<!-- TODO -->` or placeholder lines remain in generated files
- `system-context.md`: all sections filled — no empty fields
- `tech-stack.md`: specific versions or ranges, not just "React" or "Node"
- `coding-standards.md`: actionable rules enforceable by code review, not generic advice
- `api-standards.md`: URL structure and response envelope are concrete, not aspirational
- `project-config.md`: Custom Rules section has at least one entry, or explicitly states "None"
- `constitution.md`: Architecture Principles, Error Handling Contract, and Observability Contract all populated — no [PLACEHOLDER] tokens; "Not decided" only allowed in Observability Contract
- `coding-standards.md`: Formatter/Linter and Error Handling Pattern `[Fill in]` placeholders replaced with actual project values

### Workspace quality bar (WORKSPACE INIT / WORKSPACE UPDATE only)
- `projects/index.md`: count equation holds — `backendCount + frontendCount + mobileCount == totalProjects`; one router row per project; every Code Root populated
- Each project folder has all three files: `project.md`, `tech-stack.md`, `coding-standards.md` — no folder partially generated
- Each `tech-stack.md`: concrete Framework Version, never "TBD"
- Each `coding-standards.md`: Architecture Pattern recorded with at least one enforceable boundary rule
- Project folder slug matches the name used in the router row
- Shared `standards/` folder present with all three files: `api-standards.md`, `data-standards.md`, `observability-standards.md` — concrete values; "not decided yet" allowed only for observability sinks and flagged