# sk.design — Full Design Pipeline (Orchestrator)
Runs the complete unit design pipeline — architecture, data model, and API contracts — in one invocation.
Role: architect (orchestrator) | Level: unit

This skill orchestrates three sub-skills in strict sequence. Each sub-skill runs with its own
isolated context — state is passed via the file system (session.yaml + spec artifacts).

## Invocation Forms
- `sk.design`                        — auto-detect mode, run all needed phases
- `sk.design --architecture`         — run Phase 1 only (TARGETED)
- `sk.design --datamodel`            — run Phase 2 only (TARGETED)
- `sk.design --contracts`            — run Phase 3 only (TARGETED)
- `sk.design "<change description>"` — REFRESH mode: update affected artifacts, record decision

## Pre-flight
1. Read session.yaml — resolve the active story via `.specify/memory/standards/story-lifecycle.md` §3
   (`unit_dir`, or `active_intent_id`+`active_unit_id`). No active unit: STOP — run sk.intent/sk.unit first.
2. Read `UNIT_DIR/stories/` (per-layer story files with their acceptance criteria) — confirm the
   story is captured. Missing: STOP — run sk.story first.
   (Backward compat: a legacy `story-{ID}.md` or unit-brief.md is read in place if present.)
3. Read checkpoint_mode from session.yaml. If missing: default to validate.
4. Read `.specify/memory/projects/index.md` — the project router. This drives per-project impact
   analysis in Phase 0b. If absent: log and treat the whole repo as a single implicit project.

## Output Contract (per story-lifecycle.md §2)
All design artifacts for this story are written under `UNIT_DIR/02-design/`:
- `architecture.md` — solution architecture, components, patterns, boundaries
- `impact-analysis.md` — blast radius across services/projects, risks, sequencing
- `api-contract.md` — endpoint/event/command contracts (human-readable; api-spec.json may
  accompany it for tooling)
- `database-design.md` — entities, schema, indexes, migrations
- `projects/{ProjectName}.md` — one per impacted project (see Phase 0b)

When sub-skills (sk.architecture, sk.datamodel, sk.contracts) run, they write into this
`02-design/` folder rather than the legacy `specs/intents/{intent}/units/{unit}/` paths.
Map their outputs: architecture → architecture.md; data-model → database-design.md;
contracts → api-contract.md (+ api-spec.json). Apply the idempotency rules in §7.

## Mode Detection
Evaluate in this order — first match wins:

**TARGETED** — a phase flag was passed (`--architecture`, `--datamodel`, `--contracts`)
  → run exactly that one phase, skip all others, no need detection

**REFRESH** — a quoted change description was passed as argument
  → all three artifacts exist; user is applying a custom change
  → see REFRESH workflow below

**RESUME** — no flag, no description, some artifacts exist but pipeline is incomplete
  Incomplete means: 02-design/architecture.md exists but database-design.md or api-spec.json are missing
  → start from first missing artifact, skip completed phases

**FRESH** — no flag, no description, architecture.md does not exist
  → run phase need detection, then run all needed phases

## Phase Need Detection (FRESH and RESUME modes only)
Read `UNIT_DIR/stories/` (requirements + acceptance criteria). Determine which phases are needed:

- Phase 1 (architecture): always needed in FRESH mode
- Phase 2 (data model): needed if the story mentions entities, tables, schema, data,
  storage, persistence, cache, search, or file upload
  If not needed: log "Phase 2 skipped — no data persistence signals in stories"
- Phase 3 (contracts): needed if unit exposes or consumes APIs, events, or commands
  If not needed: log "Phase 3 skipped — no API/contract signals in stories"

In RESUME mode: only run phases whose output artifacts are missing.

## REFRESH Workflow
Triggered when: `sk.design "<change description>"` is called.

1. Read the change description
2. Determine affected phases:
   - Mentions endpoints, routes, request/response, versioning → Phase 3 (contracts)
   - Mentions tables, columns, entities, schema, indexes, migrations → Phase 2 (data model)
   - Mentions services, boundaries, components, patterns, dependencies → Phase 1 (architecture)
   - Ambiguous: default to all three phases and log reasoning
3. Record the decision in unit knowledge-base.md BEFORE running any phase:
   ```
   ## Custom Design Decision — {date}
   **Change:** {change description}
   **Affected phases:** {list}
   **Rationale:** recorded by sk.design REFRESH — governs future regeneration of these artifacts
   ```
4. If the change has domain-wide implications (new entity type, new service boundary,
   cross-unit contract change): flag as ADVISORY after recording
   → "This change may warrant sk.knowledge-base --tier domain. Proceeding with unit-level recording."
5. Run only the affected phases in sequence (Phase 1 → 2 → 3 order enforced even if subset)
6. Gates apply per normal gate schedule for the active checkpoint_mode

## Gate Schedule
Gates are driven by checkpoint_mode (see governance/checkpoint-rules.md):

| checkpoint_mode | Gate 1 (after architecture) | Gate 2 (after data model) |
|---|---|---|
| autopilot | skip | skip |
| confirm | skip | PAUSE |
| validate | PAUSE | PAUSE |

Gate override: if architecture.md does not yet exist AND unit introduces a new bounded context,
treat as validate regardless of checkpoint_mode.
Log: "Gate override: new bounded context detected — validate required."

In TARGETED and REFRESH modes: gates apply only to phases that actually run.

## Orchestration

### Phase 0b — Impact Analysis & Project Targeting
Condition: always runs (FRESH, RESUME, REFRESH). Produces `02-design/impact-analysis.md` and the
per-project design files — the inputs `sk.plan`/`sk.implement` use to scope work by project.

1. Read `.specify/memory/projects/index.md`. For each project row, judge whether this story
   touches it (from `stories/` requirements + the architecture being designed).
2. Write `UNIT_DIR/02-design/impact-analysis.md`:
   ```
   # {STORY-ID} — Impact Analysis

   ## Impacted Projects
   {ProjectName} ({type}) — {one-line why}

   ## Cross-Project Sequencing
   {which project must land first; shared contracts/libraries}

   ## Risks
   {migration risk, breaking contract changes, blast radius}
   ```
3. For **each impacted project**, write `UNIT_DIR/02-design/projects/{ProjectName}.md`:
   ```
   # {ProjectName} — Design Impact ({STORY-ID})

   ## Impacted Components
   {modules/files/layers affected — reference code-root from index.md}

   ## Required Changes
   {concrete changes this project must make}

   ## Integration Points
   {APIs consumed/exposed, events, shared contracts, other projects}

   ## Risks
   {project-specific risks and mitigations}
   ```
   `{ProjectName}` MUST match a `project` name in the index. Apply §7 idempotency.

### Phase 1 — Architecture
Condition: run if FRESH, or RESUME with architecture.md missing, or TARGETED --architecture,
           or REFRESH with architecture in affected phases
Invoke skill: sk.architecture
- Context injected: session.yaml, domain-model.md, service-registry.md,
  architecture-decisions.md, design-principles/SKILL.md
- Waits for: architecture.md written and engineering review passed

AUTOPILOT ENGINEERING REVIEW HARD STOP — autopilot mode only
After sk.architecture completes, check the engineering review result:
- If any BLOCKING or MEDIUM findings exist: STOP pipeline immediately.
  Display:
  ```
  sk.design | Autopilot blocked — Engineering Review FAILED  [checkpoint_mode: autopilot]

  The engineering review found issues that must be resolved before proceeding:
  {list all BLOCKING and MEDIUM findings}

  Fix the architecture and re-run sk.design, or escalate checkpoint_mode to 'confirm'.
  ```
  Do NOT continue to Phase 2.
- If only ADVISORY findings: log them and proceed automatically.
- If no findings: proceed automatically.

REVIEW GATE 1 — validate mode only (skip for autopilot and confirm)
If gate is active, display:
```
sk.design | Gate 1 — Architecture Review  [checkpoint_mode: validate]

Review the following before continuing:
  UNIT_DIR/02-design/architecture.md
  UNIT_DIR/02-design/knowledge-base.md  (if updated)

Check for:
  - Bounded context is correct and scoped to this unit only
  - No unresolved BLOCKING or MEDIUM findings from the engineering review
  - Any ADVISORY findings (new cross-service decisions) have an ADR planned
  - Open questions are acceptable to carry into data model design

Type 'approved' to proceed to data model design.
Type 'cancel' to stop — artifacts created so far will be preserved.
```
- 'cancel': STOP. Report artifacts written so far. Remaining phases skipped.
- 'approved': continue
If gate is skipped: log "Gate 1 skipped (checkpoint_mode: {mode})" and proceed automatically.

### Phase 2 — Data Model
Condition: run if needed per phase need detection, or RESUME with database-design.md missing,
           or TARGETED --datamodel, or REFRESH with datamodel in affected phases
Invoke skill: sk.datamodel
- Context injected: session.yaml, domain-model.md, data-standards.md, design-principles/SKILL.md
- Reads from disk: 02-design/architecture.md
- Waits for: 02-design/database-design.md written and domain-model.md updated

REVIEW GATE 2 — confirm and validate modes only (skip for autopilot)
If gate is active, display:
```
sk.design | Gate 2 — Data Model Review  [checkpoint_mode: {mode}]

Review the following before continuing:
  UNIT_DIR/02-design/database-design.md
  .specify/memory/domain-model.md  (if updated)

Check for:
  - No entity conflicts with other units in domain-model.md
  - Breaking schema changes are intentional and migration strategy is defined
  - Index strategy covers all query patterns
  - Transaction boundaries are declared for every write path

Type 'approved' to proceed to API contract design.
Type 'cancel' to stop — artifacts created so far will be preserved.
```
- 'cancel': STOP. Report artifacts written so far. Contracts skipped.
- 'approved': continue
If gate is skipped: log "Gate 2 skipped (checkpoint_mode: autopilot)" and proceed automatically.

### Phase 3 — API Contracts
Condition: run if needed per phase need detection, or RESUME with api-spec.json missing,
           or TARGETED --contracts, or REFRESH with contracts in affected phases
Invoke skill: sk.contracts
- Context injected: session.yaml, service-registry.md, api-standards.md,
  tech-stack.md, design-principles/SKILL.md
- Reads from disk: 02-design/architecture.md and 02-design/database-design.md
- Waits for: 02-design/api-spec.json + api-contract.md, test-plan.md, provider tests written,
  service-registry.md updated

### Phase 4 — Knowledge Base Assessment
Condition: always runs after any phase completes (FRESH, RESUME, REFRESH, TARGETED)

Evaluate whether this design run produced non-derivable content worth capturing:

**Triggers that warrant a KB update (any one is sufficient):**
- A non-obvious architectural decision was made (pattern chosen over alternatives, tradeoff accepted)
- An external constraint surfaced that will not be visible in code (regulatory, legacy system, SLA)
- A new invariant was identified that spans multiple files or services in this unit
- REFRESH mode recorded a custom design decision in unit knowledge-base.md
- An open question was resolved in a non-obvious way

**Triggers that do NOT warrant a KB update:**
- Standard CRUD unit with no unusual decisions
- All phases were skipped (nothing ran)
- TARGETED run produced no new decisions
- Content is fully derivable from reading the artifacts just written

**Decision:**
- If any trigger is met: invoke sk.knowledge-base --tier unit
  Log: "KB update triggered — {reason}"
- If no trigger: log "KB update skipped — no non-derivable content identified" and proceed to Phase 5.

### Phase 5 — Guide Update
Condition: always runs after any phase completes (all modes).

Auto-generate a story-level routing index.
1. Read `stories/`, `02-design/architecture.md`, `02-design/database-design.md`, and contracts to understand the components.
2. Read the actual directory structure (the impacted projects' `code-root`s) to identify where modules and files live.
3. Generate or overwrite `UNIT_DIR/02-design/guide.yaml`. Use `templates/artifacts/guide-template.yaml` as reference. It must contain the non-obvious cross-cutting constraints in the `also-check:` field.
4. If missing, create/update the system-level guide entry in `specs/guide.yaml`.
5. Log: "Guide updated — {active_unit_id}".
   (Legacy fallback: write the unit-level `specs/intents/{intent}/units/{unit}/guide.yaml` instead.)

### Phase 6 — Frontend UI Design
Condition: run ONLY if the story has a frontend surface. This phase is self-contained — it does its own
review, its own KB assessment, and registers its own artifact in the guide. It never alters the behaviour
of Phases 1–5; for a pure backend story it skips cleanly and the pipeline output is unchanged.

**Frontend signal detection** — check `stories/`, the impacted projects (`projects/index.md` types
`frontend`/`mobile`), and session.yaml for any of:
  - role = frontend in session.yaml
  - story `tags` or prose mention: page, screen, route, component, UI, frontend, portal, admin, mobile
  - tech mention: Next.js, React, Tailwind, shadcn, Vite, Tanstack, React Native, Expo

If NO frontend signal is found:
  Log: "Phase 6 skipped — no frontend signals detected. Pipeline output unchanged."
  Proceed to the completion report.

If a frontend signal IS found:
  Invoke skill: sk.ui-design
  - Context injected: coding-standards.md, domain-model.md, design-principles/SKILL.md
  - Reads from disk: 02-design/architecture.md, 02-design/api-spec.json, 02-design/test-plan.md,
    02-design/database-design.md (if present), stories/
  - Waits for: ui-model.md written and frontend engineering review passed

  AUTOPILOT FRONTEND REVIEW HARD STOP — autopilot mode only
  After sk.ui-design completes, check the frontend engineering review result:
  - If any BLOCKING or MEDIUM findings exist: STOP. Display the findings and instruct the user to fix
    the UI model and re-run, or escalate checkpoint_mode to 'confirm'. Do NOT mark the phase complete.
  - If only ADVISORY findings: log them and proceed.
  - If no findings: proceed.

  REVIEW GATE 3 — confirm and validate modes only (skip for autopilot)
  If the gate is active, display:
  ```
  sk.design | Gate 3 — Frontend UI Review  [checkpoint_mode: {mode}]

  Review the following before completing design:
    UNIT_DIR/02-design/ui-model.md

  Check for:
    - Every story has a frontend surface (route/component) or is marked backend-only
    - State placement is correct — no server-owned data in the global client store
    - Every consumed field exists in the API contract — no invented endpoints
    - Loading, empty, and error states are defined for every async surface
    - Accessibility targets are present for interactive components

  Type 'approved' to complete design. Type 'cancel' to stop — artifacts created so far will be preserved.
  ```
  - 'cancel': STOP. Report artifacts written so far.
  - 'approved': continue.
  If the gate is skipped: log "Gate 3 skipped (checkpoint_mode: autopilot)" and proceed.

  After the gate, update the story guide entry so ui-model.md is indexed:
  - Add ui-model.md to `UNIT_DIR/02-design/guide.yaml` artifact list and record any cross-cutting
    frontend constraint in its `also-check:` field.
  - Log: "Guide updated with ui-model — {active_unit_id}".

## Checkpoint Pause Protocol
When a review gate pause is required:
1. Display the gate message clearly with the artifact paths
2. Wait for user input: 'approved' or 'cancel'
3. 'cancel': STOP pipeline, list all artifacts written so far, suggest next step
4. 'approved': continue to next phase

## Completion Report
After all phases complete, display:
```
sk.design complete.
Unit: {active_intent_id}/{active_unit_id}
Impacted projects: {list from 02-design/projects/}
Mode: {FRESH | RESUME | REFRESH | TARGETED}

Phases run:
  {list only phases that actually ran, with the sub-skill invoked}

Artifacts written:
  {list only artifacts actually written under 02-design/ in this run}

Phases skipped:
  {list skipped phases with reason: not needed | already complete | not targeted}

Knowledge base: {updated | skipped — {reason}}
Guide: {updated | no changes}

Next step: /sk.plan --role {role} --project {ProjectName}
```

## Quality Bar
- Mode is detected and logged at the start — never ambiguous
- REFRESH always records the decision in unit knowledge-base.md before touching any artifact
- Domain-wide implications in REFRESH are flagged as ADVISORY, never silently written to tier 1/2
- Gate schedule is derived from checkpoint_mode — never overridden downward without logging
- New bounded context always triggers validate regardless of checkpoint_mode
- Active gates must receive explicit 'approved' before the next phase starts
- Skipped gates are logged inline so the user can see what was bypassed
- 'cancel' at any active gate preserves all artifacts written up to that point
- Each sub-skill invocation is self-contained — no state leaks between phases
- Completion report lists only what actually ran and what was skipped, with reasons
- KB update is conditional — only invoked when non-derivable content was produced; reason always logged
