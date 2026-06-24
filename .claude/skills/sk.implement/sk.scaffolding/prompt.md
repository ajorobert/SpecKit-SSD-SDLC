# sk.scaffolding
Structural scaffolding step for story implementation (project-scoped).
Role: backend | frontend | Level: story

Internal sub-skill — invoked by sk.implement. Do not invoke directly. The orchestrator passes the
target `{ProjectName}`.

## Path Resolution (per story-lifecycle.md §3–§4)
Resolve `STORY_DIR` from session.yaml `story_dir`. Read the plan/tasks from
`03-plan/{ProjectName}/` and `04-implementation/{ProjectName}/tasks.yaml`. Write source code under
the project's `code-root` (from `.specify/memory/projects/index.md`). Record what was scaffolded in
`04-implementation/{ProjectName}/implementation.md`. Legacy fallback (no story_dir): unit story path.

## Step 0: Capability Pack Selection
Before any other steps, load the tech stack packs relevant to this task.

1. Read session.yaml → get `role` (backend | frontend); resolve the active story (`story_dir`)
2. Read the active story frontmatter (`01-story/story.md`) → check `tags` array for domain keywords
3. Determine the target project from `{ProjectName}` and its `code-root` (projects/index.md)
4. Read applicable packs. **Load ≤6 packs total** — prioritise specialist packs when the limit is reached.

**Role = backend**
- Always: `.claude/skills/backend-feature-patterns/SKILL.md`
- `bff` → `.claude/skills/bff-patterns/SKILL.md`
- `messaging`, `events`, `queue`, `rabbitmq`, `hangfire`, `command`, `query`, `handler`, `publish`, `subscribe`, `outbox`, `saga`, `integration event`, `scheduled message`, `message bus` → `.claude/skills/wolverine-patterns/SKILL.md`
- `workflow`, `elsa`, `activity`, `signal`, `bookmark`, `human in the loop`, `hangfire`, `job`, `scheduled`, `recurring`, `cron`, `background`, `batch`, `dashboard`, `sla`, `timer`, `breach` → `.claude/skills/workflow-and-jobs-patterns/SKILL.md`
- `auth`, `authentication`, `authorization`, `jwt`, `bearer`, `keycloak`, `oidc`, `role`, `policy`, `claim`, `mfa`, `otp`, `m2m`, `user context`, `idempotency` → `.claude/skills/keycloak-patterns/SKILL.md`
- `persist`, `persistence`, `database`, `db`, `postgres`, `postgresql`, `ef core`, `dapper`, `migration`, `schema`, `jsonb`, `postgis`, `geo`, `transaction`, `repository`, `read model`, `projection`, `rls`, `tenant isolation`, `concurrency`, `xmin` → `.claude/skills/persistence-patterns/SKILL.md`
- `cache`, `caching`, `redis`, `hybrid cache`, `l1`, `l2`, `tag invalidation`, `distributed lock`, `rate limit`, `redlock`, `redis stream` → `.claude/skills/hybridcache-patterns/SKILL.md`
- `search`, `elasticsearch`, `geo` → `.claude/skills/elasticsearch-patterns/SKILL.md`
- `file`, `upload`, `attachment`, `image`, `blob`, `storage`, `seaweedfs`, `s3`, `presigned`, `virus`, `scan`, `clamav`, `imagesharp`, `resize`, `thumbnail`, `quarantine`, `exif`, `signed url`, `bucket` → `.claude/skills/file-pipeline-patterns/SKILL.md`
- `adapter`, `integration adapter`, `external service adapter`, `vendor api`, `external integration`, `DelegatingHandler`, `chain order`, `M2M handler`, `typed httpclient`, `polly`, `resilience pipeline`, `resilience handler`, `port adapter split` → `.claude/skills/integration-adapter-patterns/SKILL.md`
- `feature flag`, `feature toggle`, `feature gate`, `rollout`, `gradual release`, `percentage rollout`, `a/b test`, `variant`, `gating`, `IFeatureManager`, `IFeatureManagerSnapshot`, `IVariantFeatureManager`, `sunset`, `flag cleanup` → `.claude/skills/feature-management-patterns/SKILL.md`

**Role = frontend — Customer Portal (Next.js)**
- Always: `.claude/skills/nextjs-patterns/SKILL.md`, `.claude/skills/frontend-design-system/SKILL.md`, `.claude/skills/react-component-patterns/SKILL.md`, `.claude/skills/accessibility-standards/SKILL.md`
- `auth` → `.claude/skills/auth-patterns/SKILL.md`
- `state`, `zustand` → `.claude/skills/zustand-state-management/SKILL.md`
- `file`, `upload` → `.claude/skills/file-pipeline-patterns/SKILL.md`

**Role = frontend — Admin SPA**
- Always: `.claude/skills/react-admin-patterns/SKILL.md`, `.claude/skills/frontend-design-system/SKILL.md`, `.claude/skills/react-component-patterns/SKILL.md`, `.claude/skills/accessibility-standards/SKILL.md`
- `state`, `zustand` → `.claude/skills/zustand-state-management/SKILL.md`

**Role = frontend — Mobile**
- Always: `.claude/skills/react-native-patterns/SKILL.md`
- `auth` → `.claude/skills/auth-patterns/SKILL.md`
- `file`, `upload` → `.claude/skills/file-pipeline-patterns/SKILL.md`
List the packs loaded before continuing.

## Context Loading — cacheable (load first, in order)
1. specs/domains/{relevant-domain}/knowledge-base.md (if exists)
2. STORY_DIR/02-design/knowledge-base.md (if exists)
3. STORY_DIR/02-design/api-spec.json (if exists)
4. STORY_DIR/02-design/api-contract.md (if exists)
5. STORY_DIR/02-design/architecture.md (if exists)
6. STORY_DIR/02-design/database-design.md (if exists)
7. .specify/memory/projects/{ProjectName}/coding-standards.md + .specify/memory/standards/coding-standards.md
(Legacy fallback: specs/intents/{intent}/units/{unit}/{knowledge-base,architecture,data-model}.md + contracts/)

## Story context (tail — load LAST)
Emit at end of user-input block, after all cacheable context:
```
<story id="{story-id}">
  <story-md>…STORY_DIR/story-{ID}.md…</story-md>
  <plan-md>…STORY_DIR/plan.md…</plan-md>
  <tasks-yaml>…STORY_DIR/tasks.yaml…</tasks-yaml>
</story>
```

## Pre-generation Protocol
Before writing any code in an existing module:
1. Read the existing code in the target area. Match the established patterns.
2. Search the codebase before introducing a new abstraction (interface, utility, base class) — if an equivalent exists, use it.

## Execution Rules: Structural Scaffolding
This phase is a **pure mechanical translation** of the contracts, data models, and plan into code shape.
- **DO NOT** write business logic, implement rules, conditions, or transformations.
- **Task Tracking**: For every task where you successfully generate the structural scaffolding (stubs, classes, DTOs, etc.), update its status in `tasks.yaml` from `open` to `ready`. This signals to `sk.codegen` that the boilerplate is ready for logic implementation.

### Generate the structure:
Read `tasks.yaml` to understand *what* needs to be built, and use `api-spec.json` and `data-model.md` to know *how* it should be shaped.
1. Create directories and empty files.
2. Create classes, entities, enums, controllers, and services as stubbed boundaries.
3. Wire up dependencies via Dependency Injection signatures.
4. Implement DTOs to match API specifications exactly.
5. Create unit test files with `describe` blocks and empty `it()` stubs matching the acceptance criteria.

**Success Criteria:**
- The file structure exactly matches the plan and architecture.
- Everything compiles.
- Nothing has logic yet.
