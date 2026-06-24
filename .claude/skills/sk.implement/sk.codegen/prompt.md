# sk.codegen
Implements business logic into existing scaffolded structures (project-scoped).
Role: backend | frontend | Level: story

Internal sub-skill — invoked by sk.implement. Do not invoke directly. The orchestrator passes the
target `{ProjectName}`.

## Path Resolution (per story-lifecycle.md §3–§4)
Resolve `STORY_DIR` from session.yaml `story_dir`. Execute the tasks in
`04-implementation/{ProjectName}/tasks.yaml`, writing code under the project's `code-root` (from
`.specify/memory/projects/index.md`). As tasks complete, update
`04-implementation/{ProjectName}/{implementation.md,progress.md}` and, before handoff,
`validation.md` (build / coding-standard / design-compliance). In REFINE mode read the prior
`validation.md`. Legacy fallback (no story_dir): the unit story path + review-{story-id}.md.

## Step 0: Capability Pack Selection
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
4. STORY_DIR/02-design/architecture.md (if exists)
5. .specify/memory/projects/{ProjectName}/coding-standards.md + .specify/memory/standards/coding-standards.md
6. .specify/memory/standards/observability-standards.md
(Legacy fallback: specs/intents/{intent}/units/{unit}/{knowledge-base,architecture}.md + contracts/api-spec.json)

## Story context (tail — load LAST)
Emit at end of user-input block, after all cacheable context:
```
<story id="{story-id}">
  <story-md>…STORY_DIR/story-{ID}.md…</story-md>
  <plan-md>…STORY_DIR/plan.md…</plan-md>
  <tasks-yaml>…STORY_DIR/tasks.yaml…</tasks-yaml>
  <prior-review>…STORY_DIR/review-{story-id}.md (if REFINE mode)…</prior-review>
</story>
```

## Pre-flight for Generation
1. Check for review report: STORY_DIR/review-{story-id}.md.

## Execution Mode Detection
- `review-{story-id}.md` EXISTS → **Refine mode**: only resolve blocking findings from the review report. Do not re-execute tasks already marked [X]. Do not regenerate passing code.
- `review-{story-id}.md` ABSENT → **Normal mode**: execute tasks phase-by-phase as below.

## Execution Rules: Code Generation
You are operating on the files generated by `sk.scaffolding`.
- **Focus 100% on the rules:** Write the actual business logic, conditions, transformations, validations inside the existing structures.
- **DO NOT** make architectural decisions, move files around, or invent new abstractions without checking if they exist.
- Implementation must match contracts/api-spec.json exactly.

### Task Execution (phase-by-phase)
Parse `tasks.yaml` and execute phases in order. Do not start a phase until the prior phase is complete. Look for tasks with status `ready` (handed off by scaffolding) or `open`. Skip any task with status `done`.

Standard phase order from tasks.yaml (`phases[].id`):
- `setup`       — project structure, config, dependencies
- `foundation`  — blocking prerequisites (schema migrations, shared utilities)
- `story-N`     — user story tasks, follow TDD order (test tasks before implementation tasks)
- `crosscut`    — logging, error handling, observability

For each task:
- Tasks with `parallel: true` may execute concurrently with other `parallel:true` tasks in the same phase (or within the LLM's single output if parallel means multi-file generation).
- Respect `depends_on`: execute only after all listed task ids have status `done`.
- After completing each task: set its status to `done` in `tasks.yaml` immediately.
- Report task completion inline. If a non-parallel task fails: halt and report with context.
- Ensure coding standards are strictly followed.

## Completion Validation
After all tasks marked [X]:
1. Verify all phases complete — no unchecked tasks remain.
2. Confirm implementation matches acceptance criteria in story-{ID}.md.
3. Confirm tests were implemented.
4. Report final task count and phase summary.
