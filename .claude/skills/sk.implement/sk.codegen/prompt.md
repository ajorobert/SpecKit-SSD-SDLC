# sk.codegen
Implements business logic into existing scaffolded structures for one project.
Role: backend | frontend | mobile | Level: project

Internal sub-skill — invoked by sk.implementproject (one project of a unit). Do not invoke directly.

## Project Context (passed by sk.implementproject)
The caller passes the target `{Project}`, `{CodeRoot}`, `{ProjectType}`, the effective `--role`, and the
project slice: `03-plan/{Project}/plan.md`, `03-plan/{Project}/tasks.md`, the `02-design/` artifacts, and
in REFINE mode `04-implementation/{Project}/review-{story-id}.md`. You operate ONLY on files within
`{CodeRoot}` (and `tests/`) scaffolded by sk.scaffolding.

## Step 0: Capability Pack Selection
1. Use the `role` (backend | frontend | mobile) and `{Project}` passed by sk.implementproject
   (fall back to session.yaml `role` if not passed).
2. Read `03-plan/{Project}/plan.md` and the unit's story frontmatter → identify domain keywords.
3. Use `{ProjectType}` + the project's Role (from unit-brief Impacted Projects) as the active surface.
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
2. specs/intents/{intent}/units/{unit}/knowledge-base.md (if exists)
3. specs/intents/{intent}/units/{unit}/02-design/contracts/api-spec.json (if exists)
4. specs/intents/{intent}/units/{unit}/02-design/architecture.md (if exists)
5. specs/intents/{intent}/units/{unit}/02-design/projects/{Project}.md (if exists)
6. .specify/memory/standards/coding-standards.md
7. .specify/memory/standards/observability-standards.md

## Project context (tail — load LAST)
Emit at end of user-input block, after all cacheable context:
```
<project name="{Project}" code-root="{CodeRoot}" type="{ProjectType}">
  <plan-md>…03-plan/{Project}/plan.md…</plan-md>
  <tasks-md>…03-plan/{Project}/tasks.md…</tasks-md>
  <stories>…UNIT_DIR/01-story/ story.md, requirement.md, acceptance-criteria.md…</stories>
  <prior-review>…04-implementation/{Project}/review-{story-id}.md (if REFINE mode)…</prior-review>
</project>
```

## Pre-flight for Generation
1. Check for review report: 04-implementation/{Project}/review-{story-id}.md.

## Execution Mode Detection
- `review-{story-id}.md` EXISTS → **Refine mode**: only resolve blocking findings from the review report. Do not re-execute tasks already marked `done`. Do not regenerate passing code.
- `review-{story-id}.md` ABSENT → **Normal mode**: execute tasks in build order as below.

## Execution Rules: Code Generation
You are operating on the files generated by `sk.scaffolding`, within `{CodeRoot}`.
- **Focus 100% on the rules:** Write the actual business logic, conditions, transformations, validations inside the existing structures.
- **DO NOT** make architectural decisions, move files around, or invent new abstractions without checking if they exist.
- **Inspect before editing:** read the existing file/module first; extend additively; do not modify existing functionality or rewrite whole files unless the task requires it.
- Implementation must match contracts/api-spec.json exactly.

### Task Execution (build order)
Parse `03-plan/{Project}/tasks.md` and execute its tasks in the documented build order (the plan's
Implementation Sequence / phases). Tasks are `- [ ] T{NN} — {title}` with `depends:` lines. Cross-check
`04-implementation/{Project}/progress.md`: work tasks with status `scaffolded` (handed off by scaffolding)
or `pending`; skip any with status `done`.

For each task:
- A task marked `[P]` may execute concurrently with its parallelizable siblings (or as multi-file
  generation within a single output).
- Respect `depends:` — execute only after all listed task ids are `done`.
- After completing each task: set its status to `done` in `04-implementation/{Project}/progress.md`
  immediately (and optionally tick its `- [ ]` → `- [x]` in the plan's tasks.md).
- Report task completion inline. If a non-parallel task fails: mark it `blocked` with a reason, halt, and report with context.
- Ensure coding standards are strictly followed.

## Completion Validation
After all tasks are `done` in progress.md:
1. Verify no task remains `pending`, `scaffolded`, or `blocked` (or each remaining one is reported with a reason).
2. Confirm implementation matches the in-scope acceptance criteria in `01-story/acceptance-criteria.md` and `03-plan/{Project}/plan.md` → Test Plan.
3. Confirm tests were implemented per the plan's Test Plan.
4. Report final task count and a per-phase summary back to sk.implementproject (which records it in implementation.md / validation.md).
