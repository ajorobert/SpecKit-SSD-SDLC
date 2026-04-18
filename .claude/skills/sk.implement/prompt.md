# sk.implement
Executes implementation tasks for a story phase-by-phase.
Role: backend | frontend | Level: story

## Step 0: Capability Pack Selection
Before any other steps, load the tech stack packs relevant to this task.

1. Read session.yaml → get `role` (backend | frontend) and `active_story_id`
2. Read the active story frontmatter → check `tags` array for domain keywords
3. Determine the active service surface (from `active_unit` or story context)
4. Read applicable packs. **Load ≤6 packs total** — prioritise specialist packs when the limit is reached.

**Role = backend**
- Always: `.claude/skills/csharp-clean-arch/SKILL.md`
- `bff` → `.claude/skills/bff-patterns/SKILL.md`
- `messaging`, `events`, `queue`, `rabbitmq`, `mediatr`, `hangfire` → `.claude/skills/messaging-patterns/SKILL.md`
- `workflow`, `elsa`, `sla`, `timer`, `breach` → `.claude/skills/workflow-patterns/SKILL.md`
- `auth`, `keycloak`, `firebase`, `session`, `token` → `.claude/skills/auth-patterns/SKILL.md`
- `db`, `schema`, `migration`, `postgres`, `postgis` → `.claude/skills/postgresql-patterns/SKILL.md`
- `cache`, `redis`, `rate-limit`, `lock` → `.claude/skills/redis-patterns/SKILL.md`
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

List the packs loaded before continuing to Pre-flight.

## Pre-flight
1. Read session.yaml active_story_id
   NULL → STOP: run sk.session focus --story {id} first
2. Read session.yaml role
   NULL → STOP: run sk.session switch --role backend|frontend first
3. Resolve story directory:
   STORY_DIR = specs/intents/{intent}/units/{unit}/stories/{story-id}/
4. Verify plan.md exists: STORY_DIR/plan.md
   MISSING → STOP: run sk.plan first
5. Verify tasks.md exists: STORY_DIR/tasks.md
   MISSING → STOP: run sk.tasks first
6. Check for review report: STORY_DIR/review-{story-id}.md
   EXISTS → read it; all blocking findings MUST be resolved before proceeding

## Context loading (in order)
1. specs/domains/{relevant-domain}/knowledge-base.md (tier 2 — if exists)
2. specs/intents/{intent}/units/{unit}/knowledge-base.md (tier 3 — if exists)
   Note: knowledge bases contain non-derivable context only (the "why", not the "what")
3. STORY_DIR/plan.md — tech approach, component breakdown, data/API changes
4. STORY_DIR/tasks.md — full task list with phases and parallel markers
5. specs/intents/{intent}/units/{unit}/contracts/api-spec.json (if exists)
6. specs/intents/{intent}/units/{unit}/contracts/README.md (if exists — contains known gaps and contract decisions)
7. specs/intents/{intent}/units/{unit}/architecture.md (if exists)
8. .specify/memory/standards/coding-standards.md
9. .specify/memory/standards/observability-standards.md

## Pre-generation protocol
Before writing any code in an existing module:
1. Read the existing code in the target area. Match the established patterns.
2. Search the codebase before introducing a new abstraction (interface, utility, base class) — if an equivalent exists, use it.
This prevents session-to-session drift.

## Project setup verification
Before executing tasks, verify ignore files exist for detected stack:
- Git repo detected → ensure .gitignore exists with correct patterns
- Dockerfile present → ensure .dockerignore exists
- package.json present → ensure .npmignore exists if publishing
Create missing ignore files with standard patterns for the detected technology.
If ignore file exists: verify it contains essential patterns, append only missing critical ones.

## Execution mode detection
- review-{story-id}.md EXISTS → **Refine mode**: only resolve blocking findings from the review report. Do not re-execute tasks already marked [X]. Do not regenerate passing code.
- review-{story-id}.md ABSENT → **Normal mode**: execute tasks phase-by-phase as below.

## Status transitions
Update story-{ID}.md frontmatter at these points:
- Start of execution (normal mode): set status → in-progress
- Refine mode entry: set status → in-progress (was: review)

## Task execution (phase-by-phase)
Parse tasks.md and execute phases in order. Do not start a phase until the prior phase is complete.
Skip any task already marked [X] — do not re-execute.

Standard phase order from tasks.md:
- Phase 1: Setup — project structure, config, dependencies
- Phase 2: Foundational — blocking prerequisites (schema migrations, shared utilities)
- Phase 3+: User story tasks — follow TDD order (test tasks before their implementation tasks)
- Final phase: Cross-cutting concerns (logging, error handling, observability)

For each task:
- Tasks marked [P] may execute in parallel with other [P] tasks in the same phase
- Sequential tasks must complete before the next sequential task starts
- After completing each task: mark it [X] in tasks.md immediately
- Report task completion inline; do not batch completions
- If a non-parallel task fails: halt and report with context before proceeding

## Standards enforcement
Flag any coding-standards.md violation immediately.
Do not proceed with that task until the violation is resolved.
Implementation must match contracts/api-spec.json exactly — no undocumented deviations.

## Completion validation
After all tasks marked [X]:
1. Verify all phases complete — no unchecked tasks remain
2. Confirm implementation matches acceptance criteria in story-{ID}.md
3. Confirm tests written before implementation (TDD compliance)
4. Check for coding standards compliance
5. Report final task count and phase summary

## Output Artifacts
src/{service}/** (backend role)
src/{frontend-surface}/** (frontend role)
tasks.md (all tasks marked [X])
