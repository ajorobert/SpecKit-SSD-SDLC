# sk.scaffolding
Structural scaffolding step for story implementation.
Role: backend | frontend | Level: story

Internal sub-skill — invoked by sk.implement. Do not invoke directly.

## Step 0: Capability Pack Selection
Before any other steps, load the tech stack packs relevant to this task.

1. Read session.yaml → get `role` (backend | frontend) and `active_story_id`
2. Read the active story frontmatter → check `tags` array for domain keywords
3. Determine the active service surface (from `active_unit` or story context)
4. Read applicable packs. **Load ≤6 packs total** — prioritise specialist packs when the limit is reached.

**Role = backend**
- Always: `.claude/skills/backend-feature-patterns/SKILL.md`
- `bff` → `.claude/skills/bff-patterns/SKILL.md`
- `messaging`, `events`, `queue`, `rabbitmq`, `hangfire`, `command`, `query`, `handler`, `publish`, `subscribe`, `outbox`, `saga`, `integration event`, `scheduled message`, `message bus` → `.claude/skills/wolverine-patterns/SKILL.md`
- `workflow`, `elsa`, `sla`, `timer`, `breach` → `.claude/skills/workflow-patterns/SKILL.md`
- `auth`, `keycloak`, `firebase`, `session`, `token` → `.claude/skills/auth-patterns/SKILL.md`
- `db`, `schema`, `migration`, `postgres`, `postgis` → `.claude/skills/postgresql-patterns/SKILL.md`
- `cache`, `caching`, `redis`, `hybrid cache`, `l1`, `l2`, `tag invalidation`, `distributed lock`, `rate limit`, `redlock`, `redis stream` → `.claude/skills/hybridcache-patterns/SKILL.md`
- `search`, `elasticsearch`, `geo` → `.claude/skills/elasticsearch-patterns/SKILL.md`
- `file`, `upload`, `storage`, `image`, `virus` → `.claude/skills/file-storage-patterns/SKILL.md`

**Role = frontend — Customer Portal (Next.js)**
- Always: `.claude/skills/nextjs-patterns/SKILL.md`, `.claude/skills/frontend-design-system/SKILL.md`, `.claude/skills/react-component-patterns/SKILL.md`, `.claude/skills/accessibility-standards/SKILL.md`
- `auth` → `.claude/skills/auth-patterns/SKILL.md`
- `state`, `zustand` → `.claude/skills/zustand-state-management/SKILL.md`
- `file`, `upload` → `.claude/skills/file-storage-patterns/SKILL.md`

**Role = frontend — Admin SPA**
- Always: `.claude/skills/react-admin-patterns/SKILL.md`, `.claude/skills/frontend-design-system/SKILL.md`, `.claude/skills/react-component-patterns/SKILL.md`, `.claude/skills/accessibility-standards/SKILL.md`
- `state`, `zustand` → `.claude/skills/zustand-state-management/SKILL.md`

**Role = frontend — Mobile**
- Always: `.claude/skills/react-native-patterns/SKILL.md`
- `auth` → `.claude/skills/auth-patterns/SKILL.md`
- `file`, `upload` → `.claude/skills/file-storage-patterns/SKILL.md`
List the packs loaded before continuing.

## Context Loading — cacheable (load first, in order)
1. specs/domains/{relevant-domain}/knowledge-base.md (if exists)
2. specs/intents/{intent}/units/{unit}/knowledge-base.md (if exists)
3. specs/intents/{intent}/units/{unit}/contracts/api-spec.json (if exists)
4. specs/intents/{intent}/units/{unit}/contracts/README.md (if exists)
5. specs/intents/{intent}/units/{unit}/architecture.md (if exists)
6. specs/intents/{intent}/units/{unit}/data-model.md (if exists)
7. .specify/memory/standards/coding-standards.md

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
