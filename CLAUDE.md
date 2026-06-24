<!-- SPECKIT-SSD-SDLC MANAGED -->

> **[STACK NOTE]** This project uses .NET 10, Wolverine (not MassTransit), HybridCache (not raw Redis), FastEndpoints (not MVC), ErrorOr (not Ardalis.Result), Mapster, SeaweedFS, Tempo (not Jaeger), GlitchTip via Sentry SDK, Keycloak only (no Firebase), Strapi v5.

> **[PLACEHOLDER CONVENTION]** Skill code examples use `YourContext.*` as the .NET bounded-context root namespace placeholder (e.g. `YourContext.Api`, `YourContext.Application`). At code-generation time, substitute with the actual context name from `.specify/memory/system-context.md`. Metric/log identifiers use `directory.*` (project label) or `your-service` (URL slugs).

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
| Skill folder | Load when |
|---|---|
| `observability-contracts` | Any observability work — defines resource attrs, runtime-config JSON shape, PII deny-list, Loki label allow-list, span naming. Loaded by every observability-{backend,frontend,infra} skill. |
| `observability-infra` | OTel Collector config, Loki/Jaeger/Prometheus/GlitchTip deployment, Grafana dashboards, tail sampling, backend swap planning |

### Backend
| Skill folder | Load when |
|---|---|
| `backend-feature-patterns` | Clean Arch layers, handler shape, ErrorOr, Mapster, FluentValidation, idempotency, comment markers |
| `design-code-review` | Backend code review (sk.review) |
| `fastendpoints-patterns` | FastEndpoints v6, Scalar OpenAPI, ErrorOr→HTTP mapping, idempotency-key, throttling |
| `bff-patterns` | BFF API layer design or implementation |
| `wolverine-patterns` | Wolverine in-process + brokered messaging, outbox, sagas, scheduled messages |
| `workflow-and-jobs-patterns` | Elsa v3 long-running workflows + Hangfire background jobs, decision rule with Wolverine sagas, OTel propagation, dashboard auth |
| `keycloak-patterns` | Keycloak JWT validation, IUserContext, RBAC policies, ABAC handlers, M2M, claim mapping |
| `integration-adapter-patterns` | External integration adapter authoring: port-and-adapter split, typed HttpClient, DelegatingHandler chain, Polly v8 resilience, idempotency-aware retry |
| `feature-management-patterns` | Microsoft.FeatureManagement, IFeatureManagerSnapshot, built-in + custom filters, variant features, flag naming, sunset discipline |
| `observability-backend` | .NET service / BFF backend / Wolverine / Hangfire instrumentation (OTel, Serilog, Sentry .NET, dynamic sampler) |

### Data
| Skill folder | Load when |
|---|---|
| `persistence-patterns` | EF Core write + Dapper read, migrations, JSONB, PostGIS, RLS + TenantInterceptor, transaction + outbox binding |
| `hybridcache-patterns` | HybridCache L1+L2, tag invalidation, cross-instance cache coherence, escape hatches (locks, rate limit, streams) |
| `elasticsearch-patterns` | Elastic.Clients.Elasticsearch 8.x, geo search, Wolverine-driven indexing, alias-based reindex, tenant-isolated queries |
| `file-pipeline-patterns` | SeaweedFS storage + ImageSharp processing + nClam scanning, Wolverine upload state-machine saga, presigned uploads, ABAC for file access |

### Frontend — Customer Portal
| Skill folder | Load when |
|---|---|
| `nextjs-patterns` | Next.js App Router, NextAuth v5, Strapi CMS, R2 images |
| `frontend-design-system` | Tailwind v4, shadcn/ui, dark mode, design tokens |
| `react-component-patterns` | Component decomposition, TypeScript props, form handling |
| `zustand-state-management` | Global/shared UI state |
| `accessibility-standards` | Any frontend implementation or UAT |
| `observability-frontend` | OTel JS, Sentry, PostHog, Clarity, BFF runtime-config, source maps |

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

## Story Lifecycle (enterprise SDLC structure)
Canonical reference: `.specify/memory/standards/story-lifecycle.md` — every lifecycle skill
(sk.story, sk.design, sk.plan, sk.implement, sk.test, sk.uat, sk.security-audit, sk.session,
sk.init) loads it and resolves all artifact paths through it. Do not hardcode lifecycle paths.

Each story owns one folder with seven numbered phase folders:
```
specs/STORY-{ID}-{feature-name}/
  01-story/  02-design/  03-plan/{Project}/  04-implementation/{Project}/
  05-test/{Project}/  06-uat/  07-security-audit/
```
Flow: Story → Design → Plan → Implementation → Test → UAT → Security Audit → release readiness.
03/04/05 are project-scoped (one subfolder per participating project). Project memory lives in
`.specify/memory/projects/` — `index.md` (router: `project | type | code-root`) + per-project
`{ProjectName}/{project,tech-stack,coding-standards}.md`. Shared, cross-project standards live in
`.specify/memory/standards/` (api/data/observability + story-lifecycle).

**Backward compatibility:** the legacy `specs/intents/{intent}/units/{unit}/stories/...` layout
still resolves for read; lifecycle skills migrate it non-destructively (copy, never delete) per
story-lifecycle.md §6.

## Knowledge Bases (non-derivable context)
Tier 1 — system:  specs/knowledge-base.md
Tier 2 — domain:  specs/domains/{domain}/knowledge-base.md
Tier 3 — unit:    specs/intents/{intent}/units/{unit}/knowledge-base.md  (legacy; new stories carry KB notes in their STORY folder)

Read tier 1 before any work.
Read relevant tier 2 when working within a domain.
Read tier 3 before implementing or testing a unit.
These complement code reading — they contain only what
code cannot tell you.

<!-- END SPECKIT-SSD-SDLC MANAGED -->
