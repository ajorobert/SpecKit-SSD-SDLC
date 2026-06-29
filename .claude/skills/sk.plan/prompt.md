# sk.plan — Implementation Planning (Orchestrator)
Orchestrates technical planning for a unit, producing one execution-plan folder per impacted project.
Role: lead (orchestrator) | Level: unit

This skill orchestrates two internal sub-skills. It prepares a planning brief, invokes
`sk.planproject` once per impacted project (resolved from the unit's Impacted Projects table), and
runs `sk.analyze` at the end to catch cross-project / cross-artifact conflicts before implementation.

## Plan Output Layout
All plan artifacts for the unit live under
`specs/intents/{intent}/units/{unit}/03-plan/` — the plan sibling of `01-story/` and `02-design/`.
One folder per impacted project; folder names come from `unit-brief.md` → Impacted Projects table
(the same names sk.design used for `02-design/projects/`).

```
specs/intents/{intent}/units/{unit}/03-plan/
├── {BackendProject}/        # e.g. MarketPlace.API        (--role backend)
│   ├── plan.md              # narrative execution plan
│   ├── tasks.md             # ordered, granular task list
│   ├── checklist.md         # readiness / definition-of-done
│   ├── jira-subtask.md      # Jira sub-task breakdown
│   └── estimation.md        # per-task + rolled-up estimates
├── {CustomerWebProject}/    # e.g. MarketPlace.Customer.Web (--role frontend)
│   └── (same five files)
├── {AdminWebProject}/       # e.g. MarketPlace.Admin.Web    (--role frontend)
│   └── (same five files)
└── {MobileProject}/         # e.g. MarketPlace.Mobile       (--role mobile)
    └── (same five files)
```

Per-project folder names are dynamic — read from `unit-brief.md`. `planning-brief.md` stays at the
unit root (it is the orchestrator's cross-project synthesis, not a project artifact).

## Invocation Forms
- `sk.plan`                                   — plan ALL impacted projects missing a plan.md, then analyze
- `sk.plan --role {role} --projects {key}`    — plan exactly ONE project (TARGETED), then analyze
- `sk.plan --projects {key}`                  — plan one project; infer `--role` from project type
- `sk.plan --analyze-only`                    — skip planning, just re-run analyze
- `sk.plan --refresh "{change}"`              — update brief with change, re-plan affected projects, analyze

`--role` is one of `backend | frontend | mobile`. `--projects` is a selector resolved against the
Impacted Projects table (see Project Resolution). Examples mirroring the unit layout:
- `sk.plan --role backend  --projects api`     → `03-plan/{BackendProject}/`
- `sk.plan --role frontend --projects web`     → `03-plan/{CustomerWebProject}/`
- `sk.plan --role frontend --projects admin`   → `03-plan/{AdminWebProject}/`
- `sk.plan --role mobile   --projects mobile`  → `03-plan/{MobileProject}/`

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

When no `--projects` is given, the target set is EVERY row in the Impacted Projects table.

## Pre-flight
1. Read session.yaml — verify `active_unit_id` and `active_intent_id` are set.
   Missing: STOP — run `sk.session focus --unit {unit-id}` first.
2. Resolve `UNIT_DIR = specs/intents/{intent}/units/{unit}/` and `DESIGN_DIR = UNIT_DIR/02-design/`.
3. Verify `DESIGN_DIR/architecture.md` exists.
   Missing: STOP — run sk.design first.
4. Read `UNIT_DIR/unit-brief.md` → Impacted Projects table (the project list).
   Missing/empty: STOP — run sk.specify / sk.design first.
5. Read `DESIGN_DIR/impact-analysis.md` (per-project blast radius + sequencing). If absent, fall
   back to the unit-brief Impacted Projects table and log the degraded source.
6. Read `checkpoint_mode` from session.yaml. If missing: default to `validate`.

## Mode Detection and Resume Logic
Determine mode based on arguments and existing files. First match wins.

**TARGETED** (`--projects {key}`, with or without `--role`)
- Skip Phase 0 (Planning Brief).
- Resolve the project (Project Resolution).
- Run Phase 1 for that one project only (resume/overwrite its existing folder).
- Run Phase 2 (Analyze) and enter the Review Gate.

**TARGETED** (`--analyze-only`)
- Skip Phase 0 and Phase 1.
- Run Phase 2 (Analyze) and enter the Review Gate.

**REFRESH** (`--refresh "{change}"`)
- Run Phase 0 (Planning Brief) including the `{change}`.
- Run Phase 1 only for the projects affected by `{change}` (determine from the change text and
  impact-analysis.md; if ambiguous, re-plan all impacted projects and log the reasoning).
- Run Phase 2 (Analyze) and enter the Review Gate.

**NORMAL / RESUME** (no flags)
- If `planning-brief.md` is missing or empty: run Phase 0.
- Let `P` = every project in the Impacted Projects table.
- For each project in `P` missing `03-plan/{Project}/plan.md`: run Phase 1.
- Run Phase 2 (Analyze) and enter the Review Gate.

## Orchestration

### Phase 0 — Planning Brief
Condition: run in NORMAL/RESUME if missing; run in REFRESH. (Skipped in TARGETED.)
1. Read all of the unit's stories (`01-story/`) and `impact-analysis.md` to identify what is shared.
2. Write `UNIT_DIR/planning-brief.md`:
   - **Recommended Execution Order across projects** — sequence the impacted projects using
     `impact-analysis.md` → Sequencing & Dependencies (e.g. "infra/Keycloak realm config first;
     backend validation pipeline and the three surfaces can then proceed in parallel").
   - **Shared Infrastructure / Config Notes** — cross-project preconditions (e.g. "Keycloak realm
     + per-surface OIDC clients + tenant_id mapper must exist before any surface integrates").
   - **Cross-Project Dependencies** — explicit linkages and their direction.
   *(In REFRESH mode, document the `{change}` and its per-project impact here as well.)*

### Phase 1 — Project Planning
Condition: run for the project(s) determined by Mode Detection.
For each target project `{Project}` (with `{CodeRoot}`, `{ProjectType}` from the resolved row):
Invoke skill: `sk.planproject`
- Pass: `{Project}`, `{CodeRoot}`, `{ProjectType}`, and the effective `--role`
  (backend for Backend, frontend for Frontend, mobile for Mobile).
- Context injected: `planning-brief.md`, `02-design/architecture.md`, `02-design/impact-analysis.md`,
  `02-design/projects/{Project}.md` (if exists), `02-design/database-design.md` (if exists),
  `02-design/api-contract.md` (if exists), `02-design/contracts/api-spec.json` (if exists),
  `02-design/ui-model.md` (if exists — required for Frontend/Mobile), the unit's stories under
  `01-story/`, `tech-stack.md`, `coding-standards.md`.
- Waits for: `03-plan/{Project}/` containing plan.md, tasks.md, checklist.md, jira-subtask.md,
  estimation.md.
- Subagents are isolated from each other; independent projects may be planned in parallel.

### Phase 2 — Cross-Artifact Analysis
Condition: always runs (except if the pipeline aborted early before any plan exists).
Invoke skill: `sk.analyze`
- Context injected: all design artifacts under `02-design/`, all `03-plan/{Project}/plan.md` files.
- Waits for: the Analyze report (read-only) identifying any CRITICAL / HIGH / MEDIUM findings.

### Phase 3 — Review Gate
If `checkpoint_mode` is `confirm` or `validate`, and any new plan was generated or analyze ran:
Display:
```
sk.plan | Review Gate  [checkpoint_mode: {mode}]

Planning Brief (if generated/updated):
  specs/intents/{intent}/units/{unit}/planning-brief.md

Project Plans:
  {list every 03-plan/{Project}/ folder just generated/updated}

Analyze Report:
  {Output from sk.analyze. If there are findings, highlight them.}

Check for:
  - Project plans do not contradict each other or architecture.md
  - Every impacted project from unit-brief.md has a plan folder (or a logged reason it was skipped)
  - Files Affected / tasks.md / estimation.md are mutually consistent per project
  - No CRITICAL, HIGH, or MEDIUM findings in the analyze report

Type 'approved' to mark ALL generated plans as approved.
Type 'approved {Project} {Project}' to approve specific projects.
Type 'cancel' to stop without updating statuses.
```
- Wait for user input.
- On approval: for each approved project, set its `plan.md` front-matter `status: approved`.
- On `cancel`: leave statuses unchanged; preserve all artifacts written so far.
- If `checkpoint_mode` is `autopilot`: automatically approve all projects just planned (log it).

## Completion Report
After the pipeline completes, display:
```
sk.plan complete.
Unit: {unit-id}
Mode: {NORMAL/RESUME | TARGETED | REFRESH | ANALYZE-ONLY}

Phases run:
  {Phase 0 (Planning Brief) | Phase 1 (Projects: {list of {Project}}) | Phase 2 (Analyze)}

Plan folders written:
  {list 03-plan/{Project}/ folders, each with its five artifacts}

Projects skipped:
  {list impacted projects not planned this run, with reason: already planned | not targeted}

Analyze: {PASS | findings — {counts by severity}}

Next step: /sk.implement
```

## Quality Bar
- Mode is detected and logged at the start — never ambiguous.
- The impacted-project list is sourced from `unit-brief.md`; every impacted project is either
  planned or explicitly logged as skipped with a reason.
- `--projects` resolution is logged; `--role`/type conflicts STOP rather than guess.
- Each sk.planproject invocation is self-contained — no state leaks between projects.
- Plans never contradict `02-design/` artifacts; the orchestrator does not redesign.
- Active gates must receive explicit 'approved' before statuses change; skipped gates are logged.
- 'cancel' at the gate preserves all artifacts written up to that point.
- Completion report lists only what actually ran and what was skipped, with reasons.
