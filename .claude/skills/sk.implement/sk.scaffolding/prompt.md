# sk.scaffolding
Structural scaffolding step for one project's implementation.
Role: backend | frontend | mobile | Level: project

Internal sub-skill — invoked by sk.implementproject (one project of a unit). Do not invoke directly.

## Project Context (passed by sk.implementproject)
The caller passes the target `{Project}`, `{CodeRoot}`, `{ProjectType}`, and the effective `--role`,
plus the project slice: `03-plan/{Project}/plan.md`, `03-plan/{Project}/tasks.md`, and the relevant
`02-design/` artifacts. ALL files are created inside `{CodeRoot}` (and `tests/`), exactly as enumerated
in `03-plan/{Project}/plan.md` → Files Affected. Never write outside `{CodeRoot}`.

## Step 0: Capability Pack Selection
Before any other steps, load the tech stack packs relevant to this task.

1. Use the `role` (backend | frontend | mobile) and `{Project}` passed by sk.implementproject
   (fall back to session.yaml `role` if not passed).
2. Read `03-plan/{Project}/plan.md` and the unit's story frontmatter → identify domain keywords
   (auth, persistence, messaging, file, search, cache …).
3. Use `{ProjectType}` + the project's Role (from unit-brief Impacted Projects) as the active surface.
4. Read applicable packs. **Load ≤6 packs total** — prioritise specialist packs when the limit is reached.

**Role = backend**
- Always (canonical SSOT): `.claude/skills/backend-architecture/SKILL.md`
- Always: `.claude/skills/backend-feature-patterns/SKILL.md`
- `bff`, `aggregation`, `endpoint`, `http entry` → `.claude/skills/api-endpoint-patterns/SKILL.md`
- `messaging`, `events`, `queue`, `rabbitmq`, `hangfire`, `command`, `query`, `handler`, `publish`, `subscribe`, `outbox`, `saga`, `integration event`, `scheduled message`, `message bus`, `workflow`, `elsa`, `activity`, `signal`, `bookmark`, `human in the loop`, `job`, `scheduled`, `recurring`, `cron`, `background`, `batch`, `dashboard`, `sla`, `timer`, `breach` → `.claude/skills/orchestration-patterns/SKILL.md`
- `authorization`, `role`, `policy`, `rbac`, `abac`, `permission`, `user context`, `resource ownership`, `audit identity` → `.claude/skills/authorization-patterns/SKILL.md`
- `authentication`, `jwt`, `bearer`, `keycloak`, `oidc`, `claim`, `mfa`, `otp`, `m2m`, `claim mapping`, `composition root`, `wiring`, `outbox impl`, `transport`, `dlq` → `.claude/skills/infrastructure-wiring/SKILL.md`
- `persist`, `persistence`, `database`, `db`, `postgres`, `postgresql`, `ef core`, `dapper`, `migration`, `schema`, `jsonb`, `postgis`, `geo`, `transaction`, `repository`, `read model`, `projection`, `rls`, `tenant isolation`, `concurrency`, `xmin` → `.claude/skills/data-access-patterns/SKILL.md`
- `cache`, `caching`, `redis`, `hybrid cache`, `l1`, `l2`, `tag invalidation`, `distributed lock`, `rate limit`, `redlock`, `redis stream` → `.claude/skills/caching-patterns/SKILL.md`
- `search`, `elasticsearch`, `geo` → `.claude/skills/search-patterns/SKILL.md`
- `file`, `upload`, `attachment`, `image`, `blob`, `storage`, `seaweedfs`, `s3`, `presigned`, `virus`, `scan`, `clamav`, `imagesharp`, `resize`, `thumbnail`, `quarantine`, `exif`, `signed url`, `bucket` → `.claude/skills/file-pipeline-patterns/SKILL.md`
- `adapter`, `integration adapter`, `external service adapter`, `vendor api`, `external integration`, `DelegatingHandler`, `chain order`, `M2M handler`, `typed httpclient`, `polly`, `resilience pipeline`, `resilience handler`, `port adapter split` → `.claude/skills/integration-adapter-patterns/SKILL.md`
- `feature flag`, `feature toggle`, `feature gate`, `rollout`, `gradual release`, `percentage rollout`, `a/b test`, `variant`, `gating`, `IFeatureManager`, `IFeatureManagerSnapshot`, `IVariantFeatureManager`, `sunset`, `flag cleanup` → `.claude/skills/feature-management-patterns/SKILL.md`

**Role = frontend (surface = web | admin | mobile)**
Do NOT hardcode a per-surface pack list here. Resolve the surface and load its
packs via the shared surface-resolution preamble (same SSOT used by codegen,
review, test, verify):
1. Read `.claude/skills/shared/surface-resolution.md`.
2. It maps `{ProjectType}` + `{Project}` (unit-brief Impacted Projects) → surface,
   then loads that surface's **Always-load skill packs** from
   `.specify/memory/projects/{surface}/project.md`, plus keyword overlays
   (`state`/`zustand` → `zustand-state-management`; `auth` →
   `authorization-patterns` + `.specify/memory/auth_contract.md`; `file`/`upload`
   → `file-pipeline-patterns`). There is no `auth-patterns` skill.
List the packs loaded before continuing.

## Context Loading — cacheable (load first, in order)
1. specs/domains/{relevant-domain}/knowledge-base.md (if exists)
2. specs/intents/{intent}/units/{unit}/knowledge-base.md (if exists)
3. specs/intents/{intent}/units/{unit}/02-design/contracts/api-spec.json (if exists)
4. specs/intents/{intent}/units/{unit}/02-design/architecture.md (if exists)
5. specs/intents/{intent}/units/{unit}/02-design/projects/{Project}.md (if exists)
6. specs/intents/{intent}/units/{unit}/02-design/database-design.md (if exists)
7. specs/intents/{intent}/units/{unit}/02-design/ui-model.md (if exists — Frontend/Mobile)
8. .specify/memory/standards/coding-standards.md

## Project context (tail — load LAST)
Emit at end of user-input block, after all cacheable context:
```
<project name="{Project}" code-root="{CodeRoot}" type="{ProjectType}">
  <plan-md>…03-plan/{Project}/plan.md…</plan-md>
  <tasks-md>…03-plan/{Project}/tasks.md…</tasks-md>
  <stories>…UNIT_DIR/01-story/ story.md, requirement.md, acceptance-criteria.md…</stories>
</project>
```

## Pre-generation Protocol
Before writing any code in an existing module:
1. Read the existing code in the target area. Match the established patterns.
2. Search the codebase before introducing a new abstraction (interface, utility, base class) — if an equivalent exists, use it.

## Execution Rules: Structural Scaffolding
This phase is a **pure mechanical translation** of the contracts, data models, and plan into code shape.
- **DO NOT** write business logic, implement rules, conditions, or transformations.
- **Inspect before creating**: where the target file or module already exists, read it first and extend
  additively — do not rewrite or alter existing functionality.
- **Task Tracking**: For every task where you successfully generate the structural scaffolding (stubs,
  classes, DTOs, etc.), set its status to `scaffolded` in `04-implementation/{Project}/progress.md`. This
  signals to `sk.codegen` that the boilerplate is ready for logic implementation.

### Generate the structure:
Read `03-plan/{Project}/tasks.md` to understand *what* needs to be built (build order + Files Affected),
and use `api-spec.json`, `database-design.md`, and `ui-model.md` to know *how* it should be shaped. All
output goes inside `{CodeRoot}`.
1. Create directories and empty files.
2. Create classes, entities, enums, controllers, and services as stubbed boundaries.
3. Wire up dependencies via Dependency Injection signatures.
4. Implement DTOs to match API specifications exactly.
5. Create unit test files with `describe` blocks and empty `it()` stubs matching the acceptance criteria.

**Success Criteria:**
- The file structure exactly matches the plan and architecture.
- Everything compiles.
- Nothing has logic yet.
