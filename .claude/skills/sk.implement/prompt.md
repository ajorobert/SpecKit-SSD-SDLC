# sk.implement — Full Implementation Pipeline (Orchestrator)
Executes implementation for a story in two distinct phases: structural scaffolding, followed by code generation.
Role: backend | frontend (orchestrator) | Level: story

This skill orchestrates two sub-skills in strict sequence. Each sub-skill runs with its own isolated context — state is passed via the file system (session.yaml + spec artifacts).

## Invocation Forms
- `sk.implement`               — run both phases automatically
- `sk.implement --scaffolding` — run Phase 1 only (TARGETED)
- `sk.implement --codegen`     — run Phase 2 only (TARGETED)

## Pre-flight
1. Read session.yaml → get `role` (backend | frontend) and `active_story_id`
   NULL active_story_id → STOP: run sk.session focus --story {id} first
   NULL role → STOP: run sk.session switch --role backend|frontend first
2. Resolve story directory:
   STORY_DIR = specs/intents/{intent}/units/{unit}/stories/{story-id}/
3. Verify plan.md exists: STORY_DIR/plan.md
   MISSING → STOP: run sk.plan first
4. Verify tasks.yaml exists: STORY_DIR/tasks.yaml
   MISSING → STOP: run sk.tasks first
5. Read checkpoint_mode from session.yaml (default to validate)
6. Check for review report: STORY_DIR/review-{story-id}.md. If it exists, note it down for Execution Mode Detection.

## Execution Mode Detection
Evaluate in this order:

**TARGETED** — a phase flag was passed (`--scaffolding` or `--codegen`)
  → run exactly that one phase, skip the other.

**REFINE** — `review-{story-id}.md` EXISTS
  → Log: "Refine mode active — skipping Phase 1 (Scaffolding). Running sk.codegen to resolve review findings."
  → Run Phase 2 (sk.codegen) only.

**NORMAL** — no flag, no review report
  → Run sequence: Phase 1 (sk.scaffolding) → [Gate] → Phase 2 (sk.codegen).

## Status Transitions
Before invoking any sub-skill (in both normal or refine modes):
Update `story-{ID}.md` frontmatter `status` block:
- set `status.current` → in-progress
- set `status.entered_at` → now (ISO 8601)

## Orchestration

### Phase 1 — Structural Scaffolding
Condition: run if NORMAL, or TARGETED `--scaffolding`.
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
After pipeline completes, display:
```
sk.implement complete.
Unit: {unit-id}
Story: {story-id}
Mode: {NORMAL | REFINE | TARGETED}

Phases run:
  {list phases that actually ran: sk.scaffolding / sk.codegen}

Tasks:
  {Report final task count and phase summary from tasks.yaml}

Next step: /sk.test or /sk.review
```
