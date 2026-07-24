# sk.design — Full Design Pipeline (Orchestrator)
Runs the complete unit design pipeline — architecture, data model, and API contracts — in one invocation.
Role: architect (orchestrator) | Level: unit

This skill orchestrates three sub-skills in strict sequence. Each sub-skill runs with its own
isolated context — state is passed via the file system (session.yaml + spec artifacts).

## Design Output Layout
All design artifacts for the unit live under `specs/intents/{intent}/units/{unit}/02-design/`
— the design sibling of the story phase's `01-story/`. The pipeline produces:

```
specs/intents/{intent}/units/{unit}/02-design/
├── architecture.md       # sk.architecture — system architecture
├── impact-analysis.md    # sk.architecture — per-project blast radius (from unit-brief Impacted Projects)
├── database-design.md    # sk.datamodel  — DB/data model (successor to the old data-model.md)
├── api-contract.md       # sk.contracts  — human-readable API communication
├── ui-model.md           # sk.ui-design  — canonical frontend model (frontend units only)
├── contracts/            # sk.contracts  — machine artifacts (api-spec.json canonical, test-plan.md, README.md)
└── projects/             # one design page per impacted project (names come from unit-brief.md)
    ├── {BackendProject}.md            # sk.contracts
    └── {Frontend/MobileProject}.md    # sk.ui-design
```

Per-project file names are dynamic — read from `unit-brief.md` → Impacted Projects table.
Unit-tier `knowledge-base.md` and `guide.yaml` stay at the unit root (not under 02-design/).

## Invocation Forms
- `sk.design`                        — auto-detect: if the story declares a `## Project` section
                                       (STORY-PROJECT), scope to those projects; otherwise run
                                       Full Solution Design across all needed phases
- `sk.design --architecture`         — run Phase 1 only (TARGETED)
- `sk.design --datamodel`            — run Phase 2 only (TARGETED)
- `sk.design --contracts`            — run Phase 3 only (TARGETED)
- `sk.design {Project} [{Project} …]`           — PROJECT mode: regenerate ONLY the named project design pages
- `sk.design --project {Project} [{Project} …]` — PROJECT mode (explicit flag form, same behaviour)
- `sk.design "<change description>"` — REFRESH mode: update affected artifacts, record decision

## Pre-flight
1. Read session.yaml — verify active_unit_id and active_intent_id are set
   Either missing: STOP — run sk.session first to set the active unit
2. Read unit-brief.md — confirm it exists and is populated
   Missing: STOP — run sk.specify first to create the unit brief
3. Read checkpoint_mode from session.yaml (set by sk.specify)
   If missing: default to validate

## Mode Detection
Evaluate in this order — first match wins.

**Project-Selection Priority** — the target project(s) are chosen by the FIRST source that
applies, and later sources are ignored:
  1. Explicit project names on the command line (PROJECT mode) — always wins.
  2. The `## Project` section in the unit's story.md (STORY-PROJECT mode).
  3. Neither → full impact analysis (RESUME / FRESH).
Explicit command arguments ALWAYS override the story's `## Project` section.

**TARGETED** — a phase flag was passed (`--architecture`, `--datamodel`, `--contracts`)
  → run exactly that one phase, skip all others, no need detection

**PROJECT** — arguments name one or more projects (bare tokens or via `--project`)  [priority 1]
  A token is a project name when it EXACTLY matches (case-sensitive, no fuzzy matching) either
  a row in unit-brief.md → Impacted Projects, or an existing file name (without `.md`) under
  02-design/projects/ — e.g. `Backend.API`, `Customer.Web`, `Admin.Panel`, `Mobile.App`.
  → generate ONLY the named projects' design pages; see PROJECT workflow below.
  The story's `## Project` section is IGNORED in this mode — explicit args override it.
  If SOME tokens match project names and others do not: STOP — report each unmatched token and
  list the valid project names. Never fall through to REFRESH on a partial match.

**REFRESH** — a quoted change description was passed as argument (and no token matches a project name)
  → all three artifacts exist; user is applying a custom change
  → see REFRESH workflow below

**STORY-PROJECT** — no flag, no description, no explicit project args, AND the unit's story.md
  carries a `## Project` section (written by sk.story from Jira Components)  [priority 2]
  → read the project name(s) from that section and run the PROJECT workflow scoped to them —
    generate ONLY those `02-design/projects/{Project}.md` pages, no shared artifacts.
  → see STORY-PROJECT resolution below. This takes precedence over RESUME/FRESH: when the
    story declares its projects, sk.design does NOT run full solution analysis.

**RESUME** — no flag, no description, no `## Project` section, some artifacts exist but pipeline
  is incomplete
  Incomplete means: 02-design/architecture.md exists but 02-design/database-design.md or
  02-design/contracts/ are missing
  → start from first missing artifact, skip completed phases

**FRESH** — no flag, no description, no `## Project` section, 02-design/architecture.md does not exist  [priority 3]
  → run phase need detection, then run all needed phases (full solution design)

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

## PROJECT Workflow (project-scoped design)
Triggered when: `sk.design {Project} …` or `sk.design --project {Project} …` is called.
Full Solution Design (no arguments) is the default; PROJECT mode is a scoped regeneration that
touches ONLY the named projects' design pages under 02-design/projects/.

1. Resolve every requested name against unit-brief.md → Impacted Projects and the existing
   files under 02-design/projects/. Any name that resolves nowhere: STOP — report it and list
   the valid project names. Proceed only when every requested name resolves.
2. Read unit-brief.md and all story documents under 01-story/.
3. Read whatever shared artifacts exist — architecture.md, impact-analysis.md,
   database-design.md, api-contract.md, contracts/, ui-model.md. In this mode they are
   READ-ONLY inputs: reuse them; never create, regenerate, or overwrite any of them.
4. Split the requested projects by Type from unit-brief.md → Impacted Projects:
   - Backend rows        → invoke sk.contracts with `--project {names}` (project-scoped mode)
   - Frontend/Mobile rows → invoke sk.ui-design with `--project {names}` (project-scoped mode)
   Invoke each sub-skill at most once, passing it all of its requested projects. Each sub-skill
   writes only `02-design/projects/{ProjectName}.md` for the projects it was given.
5. If the stories show no design-relevant impact for a requested project: do NOT write an empty
   page — report "no impact found for {Project}; page not written" and continue with the rest.
6. Write scope for this mode: only `02-design/projects/{ProjectName}.md` for the requested
   projects (plus knowledge-base.md / guide.yaml via Phases 4–5). No other project page and no
   shared artifact is created, modified, or deleted.

Gates: review gates 1–3 do not apply in PROJECT mode (no shared artifacts are produced). The
sub-skills' internal engineering reviews still run, scoped to the pages actually written.
Phases 4 (KB assessment) and 5 (guide update) run as normal after the pages are written;
Phases 1–3 and 6 are skipped entirely.

## STORY-PROJECT Resolution (story-driven project scoping)
Triggered when: `sk.design` is called with NO arguments and the unit's story declares a
`## Project` section (written by sk.story from Jira Components — priority 2).

1. Read the unit's story files. For each `{NN}-story/story.md` in the unit, read the
   `## Project` section if present (single-story units are the common case — this is just
   "read story.md"). Collect the union of declared project names, de-duplicated.
   If no story has a `## Project` section: this mode does not apply — fall through to RESUME/FRESH.
2. Resolve each declared name against unit-brief.md → Impacted Projects and the project router
   (`.specify/memory/projects/index.md`). A name that resolves nowhere is reported as a warning
   and skipped (it came from the trusted mapping, so warn — do not hard-stop the run).
   If, after skipping, NO declared project resolves: log the warning and fall back to FRESH full
   solution design so the unit still gets a design.
3. Run the PROJECT Workflow above, using the resolved story-declared projects as the requested
   set. All PROJECT-mode rules apply: only `02-design/projects/{Project}.md` pages are written,
   shared artifacts are read-only, empty pages are never created, unrelated projects are untouched,
   and gates 1–3 are skipped while Phases 4–5 run.
Log at start: "STORY-PROJECT mode — scoping design to {projects} from story.md ## Project section."

## Gate Schedule
Gates are driven by checkpoint_mode (see governance/checkpoint-rules.md):

| checkpoint_mode | Gate 1 (after architecture) | Gate 2 (after data model) |
|---|---|---|
| autopilot | skip | skip |
| confirm | skip | PAUSE |
| validate | PAUSE | PAUSE |

Gate override: if 02-design/architecture.md does not yet exist AND unit introduces a new bounded context,
treat as validate regardless of checkpoint_mode.
Log: "Gate override: new bounded context detected — validate required."

In TARGETED and REFRESH modes: gates apply only to phases that actually run.
In PROJECT mode: gates 1–3 are skipped (no shared artifacts are produced); the sub-skills'
internal engineering reviews still apply to the project pages written.

## Orchestration

### Phase 1 — Architecture
Condition: run if FRESH, or RESUME with 02-design/architecture.md missing, or TARGETED --architecture,
           or REFRESH with architecture in affected phases
Invoke skill: sk.architecture
- Context injected: session.yaml, domain-model.md, service-registry.md,
  architecture-decisions.md, design-principles/SKILL.md
- Waits for: 02-design/architecture.md and 02-design/impact-analysis.md written and engineering review passed

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
  specs/intents/{intent}/units/{unit}/02-design/architecture.md
  specs/intents/{intent}/units/{unit}/02-design/impact-analysis.md
  specs/intents/{intent}/units/{unit}/knowledge-base.md  (if updated)

Check for:
  - Bounded context is correct and scoped to this unit only
  - impact-analysis.md covers every project in unit-brief.md with a change type
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
Condition: run if needed per phase need detection, or RESUME with 02-design/database-design.md missing,
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
  specs/intents/{intent}/units/{unit}/02-design/database-design.md
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
Condition: run if needed per phase need detection, or RESUME with 02-design/contracts/ missing,
           or TARGETED --contracts, or REFRESH with contracts in affected phases
Invoke skill: sk.contracts
- Context injected: session.yaml, service-registry.md, api-standards.md,
  tech-stack.md, design-principles/SKILL.md
- Reads from disk: 02-design/architecture.md, 02-design/database-design.md, unit-brief.md
- Waits for: 02-design/contracts/api-spec.json, 02-design/contracts/test-plan.md,
  02-design/api-contract.md, 02-design/projects/{BackendProject}.md, provider tests written,
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

Auto-generate a unit-level routing index.
1. Read `unit-brief.md`, `02-design/architecture.md`, `02-design/impact-analysis.md`,
   `02-design/database-design.md`, `02-design/api-contract.md`, and `02-design/contracts/`
   to understand unit components and impacted projects.
2. Read the actual directory structure (`src/**`) to identify where modules and files live.
3. Generate or overwrite `specs/intents/{intent}/units/{unit}/guide.yaml`. Use `templates/artifacts/guide-template.yaml` as reference. It must contain the non-obvious cross-cutting constraints in the `also-check:` field.
4. If missing, create/update the domain-level guide entry for this unit in `specs/domains/{domain}/guide.yaml`.
5. If missing, create/update the system-level guide entry for this domain in `specs/guide.yaml`.
6. Log: "Guide updated — {unit-id}".

### Phase 6 — Frontend UI Design
Condition: run ONLY if the unit has a frontend surface. This phase is self-contained — it does its own
review, its own KB assessment, and registers its own artifact in the guide. It never alters the behaviour
of Phases 1–5; for a pure backend unit it skips cleanly and the pipeline output is unchanged.

**Frontend signal detection** — check unit-brief.md, all stories, and session.yaml for any of:
  - role = frontend in session.yaml
  - story `tags` or prose mention: page, screen, route, component, UI, frontend, portal, admin, mobile
  - tech mention: Next.js, React, Tailwind, shadcn, Vite, Tanstack, React Native, Expo

If NO frontend signal is found:
  Log: "Phase 6 skipped — no frontend signals detected. Pipeline output unchanged."
  Proceed to the completion report.

If a frontend signal IS found:
  Invoke skill: sk.ui-design
  - Context injected: coding-standards.md, domain-model.md, design-principles/SKILL.md
  - Reads from disk: 02-design/architecture.md, 02-design/contracts/api-spec.json,
    02-design/contracts/test-plan.md, 02-design/api-contract.md,
    02-design/database-design.md (if present), unit-brief.md, stories
  - Waits for: 02-design/ui-model.md and one 02-design/projects/{Project}.md per impacted
    Frontend/Mobile project written, and frontend engineering review passed

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
    specs/intents/{intent}/units/{unit}/02-design/ui-model.md
    specs/intents/{intent}/units/{unit}/02-design/projects/  (one page per impacted Frontend/Mobile project)

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

  After the gate, update the unit guide entry so the frontend artifacts are indexed:
  - Add `02-design/ui-model.md` and the `02-design/projects/{Project}.md` frontend pages to the unit
    `specs/intents/{intent}/units/{unit}/guide.yaml` artifact list and record any cross-cutting
    frontend constraint in its `also-check:` field.
  - Log: "Guide updated with ui-model — {unit-id}".

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
Mode: {FRESH | RESUME | REFRESH | TARGETED | PROJECT | STORY-PROJECT}

Phases run:
  {list only phases that actually ran, with the sub-skill invoked}

Artifacts written:
  {list only artifacts actually written in this run}

Phases skipped:
  {list skipped phases with reason: not needed | already complete | not targeted}

Knowledge base: {updated | skipped — {reason}}
Guide: {updated | no changes}

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
- PROJECT and STORY-PROJECT modes write only the named `02-design/projects/{Project}.md` pages —
  every shared artifact (architecture.md, impact-analysis.md, database-design.md, api-contract.md,
  contracts/, ui-model.md) is read-only in those modes
- Project-selection priority is honored: explicit args > story.md `## Project` section > full
  impact analysis; explicit args always override the story's `## Project` section
- Project-name matching is exact against unit-brief.md / 02-design/projects/ — an unmatched
  name stops the run; it is never silently reinterpreted as a REFRESH description
- Empty project pages are never created — a named project with no story impact is reported
  and skipped, and unrelated projects' pages are never generated or touched
- Completion report lists only what actually ran and what was skipped, with reasons
- KB update is conditional — only invoked when non-derivable content was produced; reason always logged
