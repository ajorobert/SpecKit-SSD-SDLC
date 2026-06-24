# sk.implement — Full Implementation Pipeline (Orchestrator)
Executes implementation for a story in three distinct phases: task generation, structural scaffolding, and code generation.
Role: backend | frontend (orchestrator) | Level: story

This skill orchestrates two sub-skills in strict sequence. Each sub-skill runs with its own isolated context — state is passed via the file system (session.yaml + spec artifacts).

## Invocation Forms
- `sk.implement --project {ProjectName}`        — implement one project (recommended; project-scoped)
- `sk.implement --role {r} --project {P}`       — implement one project for an explicit role
- `sk.implement`                                — implement all planned projects for the session role
- `sk.implement --tasks`                        — run Phase 0 only (TARGETED)
- `sk.implement --scaffolding`                  — run Phase 1 only (TARGETED)
- `sk.implement --codegen`                      — run Phase 2 only (TARGETED)

## Pre-flight
1. Read session.yaml → get `role` (backend | frontend) and resolve the active story via
   `.specify/memory/standards/story-lifecycle.md` §3 (`unit_dir`).
   NULL active story → STOP: run sk.session/sk.story first.
   NULL role → STOP: run sk.session switch --role backend|frontend first.
2. **Resolve target project(s)** (per story-lifecycle.md §4):
   - `--project {ProjectName}` → that project (must exist in `.specify/memory/projects/index.md`).
   - else → every project under `UNIT_DIR/03-plan/{ProjectName}/` whose type matches the session role.
   - `PROJECT_IMPL_DIR = UNIT_DIR/04-implementation/{ProjectName}/`.
3. Verify the project plan exists: `UNIT_DIR/03-plan/{ProjectName}/plan.md`.
   MISSING → STOP: run sk.plan --project {ProjectName} first.
4. Read checkpoint_mode from session.yaml (default to validate).
5. Check for a prior review report under `04-implementation/{ProjectName}/` (or legacy
   `review-{story-id}.md`). If it exists, note it for Execution Mode Detection (REFINE).
   (Backward compat: legacy `specs/intents/**/stories/.../plan.md` is read in place if present.)

## Story context pass-through (tail — when invoking sub-skills)
When handing context to sub-skills (sk.tasks, sk.scaffolding, sk.codegen), place story/plan/review-notes in the tail after all cacheable context:
```
<story id="{story-id}" project="{ProjectName}">
  <story-md>…UNIT_DIR/stories/story-{Layer}-{ID}.md…</story-md>
  <plan-md>…UNIT_DIR/03-plan/{ProjectName}/plan.md…</plan-md>
  <tasks-md>…UNIT_DIR/03-plan/{ProjectName}/tasks.md…</tasks-md>
  <prior-review>…UNIT_DIR/04-implementation/{ProjectName}/validation.md (if REFINE mode)…</prior-review>
</story>
```
Source code is written under the project's `code-root` from `.specify/memory/projects/index.md`.

## Project Tracking Artifacts (per story-lifecycle.md §2)
For each project implemented, maintain three tracking files under
`UNIT_DIR/04-implementation/{ProjectName}/` (create if absent, update in place per §7):

**`implementation.md`** — what was built:
```
# {ProjectName} — Implementation ({STORY-ID})

## Files Changed
{path — what changed}

## Components Added
{new classes/modules/components}

## Logic Implemented
{business logic + where it lives}
```

**`progress.md`** — live status board (update as tasks move):
```
# {ProjectName} — Progress ({STORY-ID})

## Pending
- [ ] {task}

## In Progress
- [ ] {task}

## Completed
- [x] {task}
```

**`validation.md`** — self-check before handoff:
```
# {ProjectName} — Validation ({STORY-ID})

## Build Validation
{compiles / build command + result}

## Coding-Standard Validation
{checked against .specify/memory/projects/{ProjectName}/coding-standards.md + shared standards}

## Design Compliance
{matches 02-design/projects/{ProjectName}.md and architecture.md}
```

## Per-Project Loop (outermost control)
The pre-flight resolved a **target project set** (one project if `--project` was given, else every
planned project matching the session role). **Run the full Execution-Mode pipeline below once per
target project, sequentially**, in the dependency order from `03-plan/planning-brief.md` (e.g.
backend/library before the frontends that consume them). Each project's artifacts and code are
isolated under its own `04-implementation/{ProjectName}/` and `code-root`.

For each `{ProjectName}` in the target set:

## Execution Mode Detection (per project)
Evaluate in this order, scoped to the current `{ProjectName}`:

**TARGETED** — a phase flag was passed (`--tasks`, `--scaffolding`, or `--codegen`)
  → run exactly that one phase, skip all others.

**REFINE** — a review report (`04-implementation/{ProjectName}/review.md`, legacy
`review-{story-id}.md`) EXISTS
  → Log: "Refine mode active — skipping Phase 0 (Tasks) and Phase 1 (Scaffolding). Running Phase 2 (sk.codegen) to resolve review findings."
  → Run Phase 2: sk.codegen only.

**NORMAL / RESUME** — no flag, no review report
  → If `04-implementation/{ProjectName}/tasks.yaml` is missing: run Phase 0 (sk.tasks).
  → If scaffold is missing: run Phase 1 (sk.scaffolding).
  → Run Phase 2 (sk.codegen).

Pass the current `{ProjectName}` to every sub-skill invocation. After a project's pipeline
completes, append it to `session.yaml` `projects_touched`, then proceed to the next project.

## Status Transitions
Before invoking any sub-skill (in both normal or refine modes):
Update `UNIT_DIR/stories/story-{Layer}-{ID}.md` frontmatter `status` block (legacy `story-{ID}.md` if that
is the only copy), and the project's `04-implementation/{ProjectName}/progress.md`:
- set `status.current` → in-progress
- set `status.entered_at` → now (ISO 8601)

## Orchestration

### Phase 0 — Task Generation
Condition: run if NORMAL with missing `tasks.yaml`, or TARGETED `--tasks`.
Invoke skill: `sk.tasks`
- Waits for: `tasks.yaml` written in story directory.

### Phase 1 — Structural Scaffolding
Condition: run if NORMAL with missing scaffold, or TARGETED `--scaffolding`.
Invoke skill: `sk.scaffolding`
- Waits for: File structure generated, class interfaces, DTOs, and test fixtures written. Everything compiles. No business logic.

REVIEW GATE — confirm and validate modes (skip for autopilot)
If gate is active, display:
```
sk.implement | Gate — Scaffolding Review  [checkpoint_mode: {mode}]

Review the following before continuing to code generation:
  Inspect the generated structure, DTOs, interfaces, and test fixtures.

Check for:
  - File locations match the project standards.
  - No business logic was prematurely implemented.

Type 'approved' to proceed to Phase 2.
Type 'cancel' to stop — artifacts created so far will be preserved.
```
- 'cancel': STOP. Report artifacts written so far. Next phase skipped.
- 'approved': continue

### Phase 2 — Code Generation
Condition: run if NORMAL, REFINE, or TARGETED `--codegen`.
Invoke skill: `sk.codegen`
- Waits for: Business logic implemented into stubs. Tasks in `tasks.yaml` fully executed and marked done.

## Completion Report
After every target project's pipeline completes, display one block, listing each project:
```
sk.implement complete.
Unit: {active_intent_id}/{active_unit_id}
Projects implemented (in order):
  {ProjectName} ({type}) — phases run: {sk.tasks / sk.scaffolding / sk.codegen}; tracking:
    04-implementation/{ProjectName}/{implementation,progress,validation}.md
  {…repeat per project…}
Mode: {NORMAL | REFINE | TARGETED}

Next step: /sk.test --project {ProjectName}  (per project; or /sk.review)
```
