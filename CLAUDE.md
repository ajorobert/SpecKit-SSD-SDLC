<!-- SPECKIT-SSD-SDLC MANAGED -->

> **[STACK NOTE]** This project uses .NET 10 with a **seam architecture** — code targets stable seams, never the backing library. Seams: `IAppCommandBus`/`IAppQueryBus` (over Wolverine, not MassTransit), `Result<T>`/`Error` (BuildingBlocks.Contracts, not ErrorOr/Ardalis.Result), repository interfaces (over EF Core writes / Dapper reads), `HybridCache` (over Redis, not raw), `IUserContext` (over Keycloak). Edge tech: FastEndpoints (not MVC), Mapperly (not Mapster), Elasticsearch, SeaweedFS, Hangfire+Elsa v3, Tempo (not Jaeger), GlitchTip via Sentry SDK, Keycloak only (no Firebase), Strapi v5. Library names live only in `infrastructure-wiring`; `backend-architecture` is the canonical SSOT.

> **[PLACEHOLDER CONVENTION]** `BuildingBlocks.*` = the shared kernel (stable name). `YourContext.*` = one module's 4-project slice (`Contracts`/`Domain`/`Application`/`Infrastructure`); substitute the real context name at code-gen from `.specify/memory/system-context.md`. **Project facts are never hardcoded in skills** — the tenancy scope-marker names (e.g. an org/vendor marker), strongly-typed IDs, the permission catalog, schema names, cache-key prefix, and RLS column live in `.specify/memory/` and the repo's `authorization/` folder; skills reference them via placeholder + pointer (see `backend-architecture §1`). Metric/log identifiers use `directory.*` (project label) or `your-service` (URL slugs).

# SpecKit-SSD-SDLC

## Identity
Spec-driven development framework for full-stack multi-service systems.
Read .specify/project-config.md for project identity, custom rules, and overrides.
Skills: .claude/skills/sk.*/SKILL.md
Agents: .claude/agents/
Context skills: .claude/skills/{governance,design-principles,domain-model,service-registry,standards,system-context,architecture-decisions}/
Roles: po | architect | lead | backend | frontend | security

## System Prompt Inclusions
<!-- specs/knowledge-base.md is inlined at session start via @import.
     Modifying it mid-session leaves the system prompt stale.
     A PostToolUse hook will warn you when this happens — restart Claude Code to reload. -->
@specs/knowledge-base.md

## Rules
1. Skills are located in .claude/skills/sk.*/. Each skill declares its own inject_files and subagent_type. command-rules.md is no longer globally imported — relevant rules are embedded per skill.
2. Session state: .claude/session.yaml

## Tech Stack Context Skills
These are passive knowledge packs — never invoked directly. They are loaded via inject_files in the relevant sk.* skills based on the work being done.

### Cross-Cutting

Observability wiring lives in `.specify/memory/observability-stack.md` (not a skill). Skills below contain rules only — what to emit, at what level, with what properties.

### Backend
| Skill folder | Load when |
|---|---|
| `backend-architecture` | **Canonical SSOT — load for all backend work.** Seam catalog, building-blocks + module structure, Contracts primitives, comment-marker index, domain/integration event model, NetArchTest invariants, tech-per-edge |
| `backend-feature-patterns` | Clean Arch layers, handler shape, `Result<T>`/`Error`, IAppCommandBus dispatch, domain→integration events, Mapperly, FluentValidation, idempotency |
| `design-code-review` | Backend code review (sk.review) — derives checks from `backend-architecture` markers + NetArchTest invariants |
| `api-endpoint-patterns` | FastEndpoints v6, Scalar OpenAPI, `Result<T>`→HTTP mapping, idempotency-key, throttling, BFF/aggregation endpoints |
| `authorization-patterns` | `IUserContext` usage, `RequiresPermission`/`RunsAs`, RBAC policy usage, ABAC authorization handlers, predicate-scoped reads, audit identity |
| `orchestration-patterns` | Wolverine sagas + Elsa v3 workflows + Hangfire jobs; the saga/workflow/job decision rule; OTel propagation |
| `integration-adapter-patterns` | External integration adapter authoring: port-and-adapter split, typed HttpClient, DelegatingHandler chain, Polly v8 resilience, idempotency-aware retry |
| `feature-management-patterns` | Microsoft.FeatureManagement, IFeatureManagerSnapshot, built-in + custom filters, variant features, flag naming, sunset discipline |
| `observability-backend` | Traces, logs (Serilog), metrics, error sink — rules for what to emit, at what level, with what properties; PII deny-list; per-component conventions. Wiring in `.specify/memory/observability-stack.md`. |
| `infrastructure-wiring` | **Rare-load — Infrastructure/hosts only.** Seam implementations + one-time wiring: IAppCommandBus/outbox over Wolverine, EF/Dapper + TenantInterceptor registration, HybridCache+Redis, Keycloak AuthN, Hangfire/Elsa hosts + dashboards |

### Data
| Skill folder | Load when |
|---|---|
| `data-access-patterns` | EF Core write + Dapper read, repo interfaces, read services, migrations, JSONB, PostGIS, schema-per-context, optimistic concurrency, RLS + TenantInterceptor |
| `caching-patterns` | HybridCache L1+L2, tag invalidation, cross-instance cache coherence via integration events, escape hatches (locks, rate limit, streams) |
| `search-patterns` | Elastic.Clients.Elasticsearch 8.x, geo search, tenant-isolated queries, event-driven indexing, alias-based reindex, PIT+search_after pagination |
| `file-pipeline-patterns` | SeaweedFS storage + ImageSharp processing + nClam scanning, saga-driven upload state machine, presigned uploads, ABAC for file access |

### Frontend — Customer Portal
| Skill folder | Load when |
|---|---|
| `nextjs-patterns` | Next.js App Router, NextAuth v5, Strapi CMS, R2 images |
| `frontend-design-system` | Tailwind v4, shadcn/ui, dark mode, design tokens |
| `react-component-patterns` | Component decomposition, TypeScript props, form handling |
| `zustand-state-management` | Global/shared UI state |
| `accessibility-standards` | Any frontend implementation or UAT |
| `observability-frontend` | OTel JS/RN, Sentry, PostHog (anonymous), Clarity — what to capture, error boundary, source-map upload, PII redaction, consent gating. Wiring in `.specify/memory/observability-stack.md`. |

### Frontend — Admin SPA
| Skill folder | Load when |
|---|---|
| `react-admin-patterns` | React + Vite + Tanstack Router admin SPA |
| `frontend-design-system` | Tailwind v4, shadcn/ui (same as portal) |
| `react-component-patterns` | Component patterns (same as portal) |
| `zustand-state-management` | Global state (same as portal) |
| `accessibility-standards` | Any frontend implementation or UAT |
| `observability-frontend` | Same as portal — OTel JS, Sentry, PostHog, Clarity |

### Frontend — Mobile App
| Skill folder | Load when |
|---|---|
| `react-native-patterns` | React Native + Expo managed workflow, NativeWind v5 |
| `observability-frontend` | OTel RN, Sentry RN, cached runtime-config, source maps |

## Security Rules
5. Never use `rm`, `rmdir`, `del`, or `unlink` — these commands are blocked by policy.
6. To remove a file, use the archive script: `bash .claude/hooks/archive-file.sh "<relative-path>" "<reason for removal>"`
   - This moves the file to `.archive/YYYY-MM-DD/` and logs it for human review.
   - A human must review `.archive/ARCHIVE_LOG.md` before any permanent deletion.
7. Never edit or write files outside the project root directory. All file paths must resolve within the project root.
8. The `.archive/` folder is human-review territory — never delete files from it.

## Knowledge Bases (non-derivable context)
Tier 1 — system:  specs/knowledge-base.md
Tier 2 — domain:  specs/domains/{domain}/knowledge-base.md
Tier 3 — unit:    specs/intents/{intent}/units/{unit}/knowledge-base.md

Read tier 1 before any work.
Read relevant tier 2 when working within a domain.
Read tier 3 before implementing or testing a unit.
These complement code reading — they contain only what
code cannot tell you.

<!-- END SPECKIT-SSD-SDLC MANAGED -->
