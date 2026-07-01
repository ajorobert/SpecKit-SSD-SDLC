# sk.implement — Implementation Pipeline (Orchestrator)
Orchestrates the implementation phase for a unit, producing one delivery folder per impacted project.
Role: lead (orchestrator) | Level: unit

This skill orchestrates the per-project implementation worker. It resolves the impacted projects from
the unit's Impacted Projects table, invokes `sk.implementproject` once per project (each consuming that
project's already-approved `03-plan/{Project}/` plan), and gates the result before reporting. Each
sub-skill runs in its own isolated context.

## Implementation Output Layout
All implementation tracking artifacts for the unit live under
`specs/intents/{intent}/units/{unit}/04-implementation/` — the sibling of `03-plan/`.
One folder per impacted project; folder names come from `unit-brief.md` → Impacted Projects table
(the same names `sk.design` used for `02-design/projects/` and `sk.plan` used for `03-plan/`).

```
specs/intents/{intent}/units/{unit}/04-implementation/
├── {BackendProject}/       # e.g. MarketPlace.API          (--role backend)
│   ├── implementation.md   # what was built: completed tasks, changed files, decisions
│   ├── progress.md         # live task tracker (status per task from the plan's tasks.md)
│   └── validation.md       # validation status: build/test/AC results, issues, blockers
├── {CustomerWebProject}/   # e.g. MarketPlace.Customer.Web  (--role frontend)
│   └── (same three files)
├── {AdminWebProject}/      # e.g. MarketPlace.Admin.Web     (--role frontend)
│   └── (same three files)
└── {MobileProject}/        # e.g. MarketPlace.Mobile        (--role mobile)
    └── (same three files)
```

Per-project folder names are dynamic — read from `unit-brief.md`. Actual source code is written within
each project's `{CodeRoot}` (from the Impacted Projects table), NOT under `04-implementation/`. The
`04-implementation/{Project}/` folder holds only the delivery-tracking docs.

## Invocation Forms
- `sk.implement`                                 — implement ALL impacted projects that have an approved plan
- `sk.implement --role {role} --projects {key}`  — implement exactly ONE project (TARGETED)
- `sk.implement --projects {key}`                — implement one project; infer `--role` from project type
- `sk.implement --refine`                        — re-run code generation only, for projects with a review report

`--role` is one of `backend | frontend | mobile`. `--projects` is a selector resolved against the
Impacted Projects table (see Project Resolution). Examples mirroring the unit layout:
- `sk.implement --role backend  --projects api`     → `04-implementation/{BackendProject}/`
- `sk.implement --role frontend --projects web`     → `04-implementation/{CustomerWebProject}/`
- `sk.implement --role frontend --projects admin`   → `04-implementation/{AdminWebProject}/`
- `sk.implement --role mobile   --projects mobile`  → `04-implementation/{MobileProject}/`

## Project Resolution
Resolve a `--projects {key}` selector to a row in `unit-brief.md` → Impacted Projects:
1. Exact match on the project Name (e.g. `--projects MarketPlace.API`).
2. Well-known aliases against the row's Type / Role:
   - `api` | `backend`  → the row with Type = Backend
   - `web` | `customer` → the Frontend row whose Role mentions customer/portal
   - `admin`            → the Frontend row whose Role mentions admin
   - `mobile`           → the row with Type = Mobile
3. If `--role` is also given, it must agree with the resolved row's Type (backend↔Backend,
   frontend↔Frontend, mobile↔Mobile). On conflict: STOP and report the mismatch.
4. If a selector matches zero or more than one row: STOP and list the candidate projects.
Log the resolution: `Resolved --projects {key} → {Project} ({Type}, {CodeRoot})`.

When no `--projects` is given, the target set is EVERY row in the Impacted Projects table that has an
approved `03-plan/{Project}/plan.md`.

## Pre-flight
1. Read session.yaml — verify `active_unit_id` and `active_intent_id` are set.
   Missing: STOP — run `sk.session focus --unit {unit-id}` first.
2. Resolve `UNIT_DIR = specs/intents/{intent}/units/{unit}/`, `PLAN_DIR = UNIT_DIR/03-plan/`,
   `IMPL_DIR = UNIT_DIR/04-implementation/`, `DESIGN_DIR = UNIT_DIR/02-design/`.
3. Read `UNIT_DIR/unit-brief.md` → Impacted Projects table (the project list + Code Root per project).
   Missing/empty: STOP — run sk.specify / sk.design first.
4. Verify `PLAN_DIR` exists with at least one `03-plan/{Project}/plan.md`.
   Missing: STOP — run sk.plan first.
5. Read `checkpoint_mode` from session.yaml. If missing: default to `validate`.
6. Read the unit's stories under `01-story/` to know the acceptance criteria the implementation must satisfy.

## Mode Detection and Resume Logic
Determine mode based on arguments and existing files. First match wins.

**TARGETED** (`--projects {key}`, with or without `--role`)
- Resolve the project (Project Resolution).
- Run Phase 1 for that one project only (resume/overwrite its `04-implementation/{Project}/` folder).
- Run Phase 2 (Review Gate) and report.

**REFINE** (`--refine`, OR a `review-{story-id}.md` exists for a targeted/impacted project)
- For each in-scope project that has a `review-{story-id}.md`: invoke `sk.implementproject` in REFINE
  mode (code generation only — resolve review findings, no re-scaffolding).
- Run Phase 2 (Review Gate) and report.

**NORMAL / RESUME** (no flags)
- Let `P` = every project in the Impacted Projects table that has an approved `03-plan/{Project}/plan.md`.
- For each project in `P`:
  - If `04-implementation/{Project}/progress.md` is missing or has open tasks: run Phase 1 for it.
  - If `04-implementation/{Project}/` is complete (all tasks done, validation PASS): skip it (log "already implemented").
- Run Phase 2 (Review Gate) and report.

Projects in the Impacted Projects table with NO approved plan are skipped and logged with a reason
(`no plan — run sk.plan --projects {key}` or `plan not approved`).

## Status Transitions
Before invoking the first project worker, update the unit's story frontmatter in `01-story/story.md`
(or `story-{ID}.md`):
- set `status.current` → in-progress
- set `status.entered_at` → now (ISO 8601)

## Orchestration

### Phase 1 — Per-Project Implementation
Condition: run for the project(s) determined by Mode Detection.
For each target project `{Project}` (with `{CodeRoot}`, `{ProjectType}` from the resolved row):
Invoke skill: `sk.implementproject`
- Pass: `{Project}`, `{CodeRoot}`, `{ProjectType}`, the effective `--role`
  (backend for Backend, frontend for Frontend, mobile for Mobile), and the execution mode
  (NORMAL or REFINE).
- Context injected: `03-plan/{Project}/plan.md`, `03-plan/{Project}/tasks.md`,
  `03-plan/{Project}/checklist.md`, `02-design/projects/{Project}.md` (if exists),
  `02-design/architecture.md`, `02-design/contracts/api-spec.json` (if exists),
  `02-design/database-design.md` (if exists), `02-design/ui-model.md` (if exists — Frontend/Mobile),
  the unit's stories under `01-story/`, `coding-standards.md`, the project's `review-{story-id}.md`
  (if REFINE mode).
- Waits for: `04-implementation/{Project}/` containing implementation.md, progress.md, validation.md,
  and the actual source written within `{CodeRoot}`.
- Subagents are isolated from each other. Honor cross-project sequencing from
  `02-design/impact-analysis.md` → Sequencing & Dependencies: a project blocked on another project's
  output (or shared infra/config) runs after its precondition; independent projects may run in parallel.

### Phase 2 — Review Gate
If `checkpoint_mode` is `confirm` or `validate`, and any project was implemented this run:
Display:
```
sk.implement | Review Gate  [checkpoint_mode: {mode}]

Projects implemented:
  {list every 04-implementation/{Project}/ folder just generated/updated}

Per-project validation:
  {for each project: build status, test status, AC coverage, open issues — from validation.md}

Check for:
  - Implementation stays inside each project's plan slice (no scope creep into another project)
  - Existing functionality was not modified beyond the planned change set
  - progress.md tasks match 03-plan/{Project}/tasks.md (every task accounted for)
  - validation.md reports build + tests + acceptance-criteria status honestly (failures surfaced, not hidden)
  - No project contradicts architecture.md or the API contract

Type 'approved' to mark ALL implemented projects as approved.
Type 'approved {Project} {Project}' to approve specific projects.
Type 'cancel' to stop without updating statuses.
```
- Wait for user input.
- On approval: for each approved project, set its `04-implementation/{Project}/implementation.md`
  front-matter `status: approved`.
- On `cancel`: leave statuses unchanged; preserve all artifacts and source written so far.
- If `checkpoint_mode` is `autopilot`: automatically approve all projects just implemented (log it).

## Completion Report
After the pipeline completes, display:
```
sk.implement complete.
Unit: {unit-id}
Mode: {NORMAL/RESUME | TARGETED | REFINE}

Phases run:
  Phase 1 (Projects: {list of {Project}})
  Phase 2 (Review Gate)

Implementation folders written:
  {list 04-implementation/{Project}/ folders, each with implementation.md, progress.md, validation.md}

Source roots touched:
  {list each project's {CodeRoot}}

Projects skipped:
  {list impacted projects not implemented this run, with reason: no plan | plan not approved | already implemented | not targeted}

Validation: {per project — build PASS/FAIL, tests PASS/FAIL/n, AC covered/total}

Next step: /sk.test or /sk.review
```

## Quality Bar
- Mode is detected and logged at the start — never ambiguous.
- The impacted-project list is sourced from `unit-brief.md`; every impacted project is either
  implemented or explicitly logged as skipped with a reason.
- `--projects` resolution is logged; `--role`/type conflicts STOP rather than guess.
- Each `sk.implementproject` invocation is self-contained — no state leaks between projects.
- Implementation realizes `03-plan/{Project}/` and `02-design/` — the orchestrator does not redesign or re-plan.
- Existing functionality is never modified beyond the planned change set; new code is added, files are
  inspected before editing, and complete files are not rewritten unless required.
- Active gates must receive explicit 'approved' before statuses change; skipped gates are logged.
- 'cancel' at the gate preserves all artifacts and source written up to that point.
- Completion report lists only what actually ran and what was skipped, with reasons.
