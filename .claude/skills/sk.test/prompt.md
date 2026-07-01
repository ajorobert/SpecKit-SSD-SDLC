# sk.test — Testing Pipeline (Orchestrator)
Orchestrates the testing phase for a unit, producing one test folder per impacted project.
Role: lead (orchestrator) | Level: unit

This skill orchestrates the per-project test worker. It resolves the impacted projects from the
unit's Impacted Projects table, invokes `sk.testproject` once per project (each consuming that
project's design slice plus the unit's `02-design/contracts/`), and gates the result before
reporting. Each sub-skill runs in its own isolated context.

## Test Output Layout
All test-design / test-tracking artifacts for the unit live under
`specs/intents/{intent}/units/{unit}/05-test/` — the sibling of `04-implementation/`.
One folder per impacted project; folder names come from `unit-brief.md` → Impacted Projects table
(the same names `sk.design` used for `02-design/projects/`, `sk.plan` used for `03-plan/`, and
`sk.implement` used for `04-implementation/`).

```
specs/intents/{intent}/units/{unit}/05-test/
├── {BackendProject}/        # e.g. MarketPlace.API           (--role backend)
│   ├── unit-test.md         # unit test cases + expected results (handlers, mappers, validators)
│   ├── integration-test.md  # service + database/pipeline integration cases + expected results
│   └── contract-test.md     # PROVIDER contracts: every endpoint in api-spec.json + regression checks
├── {CustomerWebProject}/    # e.g. MarketPlace.Customer.Web   (--role frontend)
│   ├── component-test.md     # component/UI test cases + expected results
│   └── contract-test.md      # CONSUMER contracts: endpoints/claims this surface depends on
├── {AdminWebProject}/       # e.g. MarketPlace.Admin.Web      (--role frontend)
│   └── (component-test.md, contract-test.md)
└── {MobileProject}/         # e.g. MarketPlace.Mobile         (--role mobile)
    └── (component-test.md, contract-test.md)
```

Per-project folder names are dynamic — read from `unit-brief.md`. The actual runnable tests are
written within each project's test tree under its `{CodeRoot}` (e.g. `tests/contract/{unit}/provider/`),
NOT under `05-test/`. The `05-test/{Project}/` folder holds only the test-design / tracking docs
(test cases, expected results, provider/consumer contracts, regression checks).

## Invocation Forms
- `sk.test`                                   — test ALL impacted projects that have an implementation
- `sk.test --role {role} --projects {key}`    — test exactly ONE project (TARGETED)
- `sk.test --projects {key}`                  — test one project; infer `--role` from project type
- `sk.test --refine`                          — re-run test generation only, for projects whose tests failed

`--role` is one of `backend | frontend | mobile`. `--projects` is a selector resolved against the
Impacted Projects table (see Project Resolution). Examples mirroring the unit layout:
- `sk.test --role backend  --projects api`     → `05-test/{BackendProject}/`
- `sk.test --role frontend --projects web`     → `05-test/{CustomerWebProject}/`
- `sk.test --role frontend --projects admin`   → `05-test/{AdminWebProject}/`
- `sk.test --role mobile   --projects mobile`  → `05-test/{MobileProject}/`

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
implementation under `04-implementation/{Project}/` (or, if implementation tracking is absent, an
approved plan under `03-plan/{Project}/`).

## Pre-flight
1. Read session.yaml — verify `active_unit_id` and `active_intent_id` are set.
   Missing: STOP — run `sk.session focus --unit {unit-id}` first.
2. Resolve `UNIT_DIR = specs/intents/{intent}/units/{unit}/`, `DESIGN_DIR = UNIT_DIR/02-design/`,
   `IMPL_DIR = UNIT_DIR/04-implementation/`, `TEST_DIR = UNIT_DIR/05-test/`.
3. Read `UNIT_DIR/unit-brief.md` → Impacted Projects table (the project list + Code Root per project).
   Missing/empty: STOP — run sk.specify / sk.design first.
4. Verify `DESIGN_DIR/contracts/test-plan.md` and `DESIGN_DIR/contracts/api-spec.json` exist.
   Missing: WARN — proceed, but flag that contract tests are unanchored (sk.design --contracts not run).
5. Read `checkpoint_mode` from session.yaml. If missing: default to `validate`.
6. Read the unit's stories under `01-story/` to know the acceptance criteria the tests must cover, and
   `UNIT_DIR/knowledge-base.md` (tier 3 invariants inform test design) if it exists.

## Mode Detection and Resume Logic
Determine mode based on arguments and existing files. First match wins.

**TARGETED** (`--projects {key}`, with or without `--role`)
- Resolve the project (Project Resolution).
- Run Phase 1 for that one project only (resume/overwrite its `05-test/{Project}/` folder).
- Run Phase 2 (Review Gate) and report.

**REFINE** (`--refine`, OR a project's `05-test/{Project}/` reports failing tests)
- For each in-scope project whose last run reported failures: invoke `sk.testproject` in REFINE mode
  (regenerate/repair only the failing tests; do not discard passing ones).
- Run Phase 2 (Review Gate) and report.

**NORMAL / RESUME** (no flags)
- Let `P` = every project in the Impacted Projects table that has an implementation
  (`04-implementation/{Project}/`) or an approved plan (`03-plan/{Project}/plan.md`).
- For each project in `P`:
  - If `05-test/{Project}/` is missing or reports open/failing cases: run Phase 1 for it.
  - If `05-test/{Project}/` is complete (all cases written, suite green): skip it (log "already tested").
- Run Phase 2 (Review Gate) and report.

Projects in the Impacted Projects table with NO implementation and NO approved plan are skipped and
logged with a reason (`no implementation — run sk.implement --projects {key}`).

## Orchestration

### Phase 1 — Per-Project Testing
Condition: run for the project(s) determined by Mode Detection.
For each target project `{Project}` (with `{CodeRoot}`, `{ProjectType}` from the resolved row):
Invoke skill: `sk.testproject`
- Pass: `{Project}`, `{CodeRoot}`, `{ProjectType}`, the effective `--role`
  (backend for Backend, frontend for Frontend, mobile for Mobile), and the execution mode
  (NORMAL or REFINE).
- Context injected: `02-design/contracts/test-plan.md`, `02-design/contracts/api-spec.json`,
  `02-design/projects/{Project}.md` (if exists), `02-design/architecture.md`,
  `02-design/database-design.md` (if exists), `02-design/ui-model.md` (if exists — Frontend/Mobile),
  `03-plan/{Project}/plan.md` → Test Plan (if exists), `04-implementation/{Project}/` (if exists —
  what was actually built), the unit's stories under `01-story/`, `UNIT_DIR/knowledge-base.md`,
  `tech-stack.md`.
- Waits for: `05-test/{Project}/` containing the per-type test docs (Backend: unit-test.md,
  integration-test.md, contract-test.md; Frontend/Mobile: component-test.md, contract-test.md), and
  the actual runnable tests written within `{CodeRoot}`'s test tree.
- Subagents are isolated from each other. Backend provider contracts are the source of truth for
  Frontend/Mobile consumer contracts — if both run, honor that direction; independent projects may
  run in parallel.

### Phase 2 — Review Gate
If `checkpoint_mode` is `confirm` or `validate`, and any project was tested this run:
Display:
```
sk.test | Review Gate  [checkpoint_mode: {mode}]

Projects tested:
  {list every 05-test/{Project}/ folder just generated/updated}

Per-project test results:
  {for each project: cases written, suite PASS/FAIL/n green, AC covered/total, endpoints covered — from its test docs}

Check for:
  - Every endpoint in api-spec.json has a provider contract test (backend projects)
  - Every consumed endpoint/claim has a consumer contract test (frontend/mobile projects)
  - Every acceptance criterion maps to at least one integration/component/E2E test
  - Regression checks present and passing; no skipped/pending tests
  - No test contradicts the api-spec.json contract or the implementation actually built
  - test-coverage rubric (this skill's SKILL.md) is satisfied

Type 'approved' to roll the unit test-status up to pass for ALL tested projects.
Type 'approved {Project} {Project}' to approve specific projects.
Type 'cancel' to stop without updating statuses.
```
- Wait for user input.
- On approval: set the unit's story frontmatter `test-status` (in `01-story/story.md` or
  `story-{ID}.md`) — `pass` only if EVERY in-scope project's suite is green; otherwise leave `fail`
  with the failing projects noted.
- On `cancel`: leave statuses unchanged; preserve all test docs and tests written so far.
- If `checkpoint_mode` is `autopilot`: automatically roll up `test-status` from the per-project
  results (pass iff all green) and log it.

## Completion Report
After the pipeline completes, display:
```
sk.test complete.
Unit: {unit-id}
Mode: {NORMAL/RESUME | TARGETED | REFINE}

Phases run:
  Phase 1 (Projects: {list of {Project}})
  Phase 2 (Review Gate)

Test folders written:
  {list 05-test/{Project}/ folders, each with its per-type test docs}

Test roots touched:
  {list each project's {CodeRoot} test tree}

Projects skipped:
  {list impacted projects not tested this run, with reason: no implementation | already tested | not targeted}

Results: {per project — suite PASS/FAIL/n green, AC covered/total, endpoints covered/total}

Roll-up: test-status = {pass | fail}

Next step: /sk.uat (frontend surfaces) or /sk.security-audit
```

## Quality Bar
- Mode is detected and logged at the start — never ambiguous.
- The impacted-project list is sourced from `unit-brief.md`; every impacted project is either tested
  or explicitly logged as skipped with a reason.
- `--projects` resolution is logged; `--role`/type conflicts STOP rather than guess.
- Each `sk.testproject` invocation is self-contained — no state leaks between projects.
- Tests realize `02-design/contracts/` and the unit's acceptance criteria — the orchestrator does not
  redesign contracts or invent endpoints.
- Existing tests are never discarded on REFINE; only failing cases are repaired.
- Active gates must receive explicit 'approved' before `test-status` changes; skipped gates are logged.
- 'cancel' at the gate preserves all artifacts and tests written up to that point.
- `test-status` rolls up honestly — `pass` only when every in-scope project's suite is green.
- Completion report lists only what actually ran and what was skipped, with reasons.

## Completion Signal
Last line of output must be exactly one of:
`SK_RESULT: PASS` — all in-scope projects' suites passed
`SK_RESULT: FAIL` — one or more projects have failing or missing required tests
