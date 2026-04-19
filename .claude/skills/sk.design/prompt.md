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
1. Read session.yaml — verify active_unit_id and active_intent_id are set
   Either missing: STOP — run sk.session first to set the active unit
2. Read unit-brief.md — confirm it exists and is populated
   Missing: STOP — run sk.specify first to create the unit brief
3. Read checkpoint_mode from session.yaml (set by sk.specify)
   If missing: default to validate

## Mode Detection
Evaluate in this order — first match wins:

**TARGETED** — a phase flag was passed (`--architecture`, `--datamodel`, `--contracts`)
  → run exactly that one phase, skip all others, no need detection

**REFRESH** — a quoted change description was passed as argument
  → all three artifacts exist; user is applying a custom change
  → see REFRESH workflow below

**RESUME** — no flag, no description, some artifacts exist but pipeline is incomplete
  Incomplete means: architecture.md exists but data-model.md or contracts/ are missing
  → start from first missing artifact, skip completed phases

**FRESH** — no flag, no description, architecture.md does not exist
  → run phase need detection, then run all needed phases

## Phase Need Detection (FRESH and RESUME modes only)
Read all stories in the unit. Determine which phases are needed:

- Phase 1 (architecture): always needed in FRESH mode
- Phase 2 (data model): needed if stories mention entities, tables, schema, data,
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
  specs/intents/{intent}/units/{unit}/architecture.md
  specs/intents/{intent}/units/{unit}/knowledge-base.md  (if updated)

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
Condition: run if needed per phase need detection, or RESUME with data-model.md missing,
           or TARGETED --datamodel, or REFRESH with datamodel in affected phases
Invoke skill: sk.datamodel
- Context injected: session.yaml, domain-model.md, data-standards.md, design-principles/SKILL.md
- Reads from disk: architecture.md
- Waits for: data-model.md written and domain-model.md updated

REVIEW GATE 2 — confirm and validate modes only (skip for autopilot)
If gate is active, display:
```
sk.design | Gate 2 — Data Model Review  [checkpoint_mode: {mode}]

Review the following before continuing:
  specs/intents/{intent}/units/{unit}/data-model.md
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
Condition: run if needed per phase need detection, or RESUME with contracts/ missing,
           or TARGETED --contracts, or REFRESH with contracts in affected phases
Invoke skill: sk.contracts
- Context injected: session.yaml, service-registry.md, api-standards.md,
  tech-stack.md, design-principles/SKILL.md
- Reads from disk: architecture.md and data-model.md
- Waits for: api-spec.json, test-plan.md, provider tests written,
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
- If no trigger: log "KB update skipped — no non-derivable content identified" and proceed to
  Completion Report

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
Unit: {unit-id} — {unit name}
Intent: {intent-id}
Mode: {FRESH | RESUME | REFRESH | TARGETED}

Phases run:
  {list only phases that actually ran, with the sub-skill invoked}

Artifacts written:
  {list only artifacts actually written in this run}

Phases skipped:
  {list skipped phases with reason: not needed | already complete | not targeted}

Knowledge base: {updated | skipped — {reason}}

Next step: /sk.plan
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
