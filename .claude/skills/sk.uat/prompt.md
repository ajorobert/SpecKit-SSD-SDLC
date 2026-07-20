# sk.uat — User Acceptance Testing (Unit)
User Acceptance Testing for a unit against its acceptance criteria, across every impacted surface.
Role: frontend-qa | Level: unit
Frontend only — backend uses sk.test for contract and integration tests.

UAT is a unit-level acceptance gate. Its output is a single flat `06-uat/` folder for the unit (NOT
one folder per project): the impacted surfaces are exercised and their results are aggregated into
one acceptance record, one user-flow record, and one sign-off.

## Step 0: Capability Pack Selection
Resolve the in-scope surfaces first (see Surface Resolution), then load each
surface's packs via the shared surface-resolution preamble — do NOT hardcode a
per-surface list (UAT must exercise the code under the same packs it was built
and reviewed under):
- Read `.claude/skills/shared/surface-resolution.md`.
- For **each** in-scope surface (`web` = customer-portal / `admin` = tagin-console,
  both Next.js / `mobile` = vendor-app, RN), load its **Always-load skill packs**
  from `.specify/memory/projects/{surface}/project.md`. This loads
  `accessibility-standards` (Part A everywhere; Part B on web/admin) and
  `observability-frontend` on every surface. `admin` uses `nextjs-patterns` +
  `nextjs-admin-patterns` (there is no `react-admin-patterns`).

List the packs loaded before continuing.

## Invocation Forms
- `sk.uat`                          — UAT for ALL impacted user-facing surfaces of the unit
- `sk.uat --platform {surface}`     — UAT for ONE surface only (`web | admin | mobile`)

`--platform` narrows the run to a single surface; otherwise every impacted Frontend/Mobile project in
the unit is exercised.

## Surface Resolution
Resolve the in-scope surfaces from `unit-brief.md` → Impacted Projects (Frontend/Mobile rows only):
- `web`    → the Frontend row whose Role mentions customer/portal (e.g. MarketPlace.Customer.Web)
- `admin`  → the Frontend row whose Role mentions admin (e.g. MarketPlace.Admin.Web)
- `mobile` → the row with Type = Mobile (e.g. MarketPlace.Mobile)
Backend rows are NOT user-facing surfaces — they are excluded from UAT (covered by sk.test).
- With `--platform {surface}`: resolve that one row; if it is not an impacted project, STOP and report.
- Without a flag: the surface set is every Frontend/Mobile row in the Impacted Projects table.
Log the resolution: `UAT surfaces: {list of {Project} (surface)}`.
If the unit impacts NO user-facing surface: STOP — "Unit {unit-id} has no frontend/mobile surface;
UAT is N/A. Backend verification is covered by sk.test."

## Pre-flight
1. Read session.yaml — verify `active_unit_id` and `active_intent_id` are set.
   Missing: STOP — run `sk.session focus --unit {unit-id}` first.
2. Resolve `UNIT_DIR = specs/intents/{intent}/units/{unit}/`, `DESIGN_DIR = UNIT_DIR/02-design/`,
   `UAT_DIR = UNIT_DIR/06-uat/`.
3. Read `UNIT_DIR/unit-brief.md` → Impacted Projects table. Missing/empty: STOP.
4. Read `checkpoint_mode` from session.yaml. If missing: default to `validate`.

## Context loading
- UNIT_DIR/01-story/ story.md, requirement.md, acceptance-criteria.md
  → each acceptance criterion becomes a UAT scenario; the requirement's business rules become the
    validation checklist.
- DESIGN_DIR/contracts/test-plan.md → Consumer Tests section, per surface:
    - web    → `## Consumer Tests / ### web`
    - mobile → `## Consumer Tests / ### mobile`
    - admin  → `## Consumer Tests / ### admin`
- DESIGN_DIR/ui-model.md (if exists) → the end-to-end user flows to walk.
- UNIT_DIR/knowledge-base.md (if exists) → non-obvious invariants the UAT must respect (e.g.
  no user enumeration, no partial session on failure, security-relevant copy).
- UNIT_DIR/05-test/{Surface}/ (if exists) → component/consumer results already produced by sk.test,
  so UAT focuses on end-user workflow rather than re-running unit-level checks.

## Test execution by surface
For each in-scope surface, declare it, then exercise it with the correct tooling:

### web (Next.js — Customer.Web)
- Tooling: Playwright or Cypress (per tech-stack.md)
- Scenarios: full browser E2E, user journey flows, responsive layout, error/empty states.

### admin (Next.js — Admin.Web / tagin-console)
- Tooling: Playwright or Cypress (per tech-stack.md)
- Scenarios: CRUD operations, bulk actions, role-based visibility, data-table pagination.

### mobile (React Native — Mobile)
- Tooling: Maestro or Detox (per tech-stack.md). No browser — never use Playwright/Cypress for mobile.
- Scenarios: device/simulator flows, offline behaviour, deep links, push-notification handling, secure
  storage of tokens.

Run each surface's scenarios against the acceptance criteria; capture pass/fail per criterion per
surface, plus any business-rule violation observed.

## Output Artifacts
Write the flat unit-level UAT folder `UNIT_DIR/06-uat/`:

### acceptance-result.md
Per-criterion acceptance results across all surfaces.
```
---
unit: {unit-id}
intent: {intent-id}
surfaces: [{list of surfaces exercised}]
created: {today}
updated: {today}
---

# UAT Acceptance Results: {unit name} ({unit-id})

## Acceptance Criteria
Table: | AC | Criterion | {surface} result … | Verdict | Notes |
One row per acceptance criterion; one result column per in-scope surface (PASS / FAIL / N-A).
Verdict is PASS only if every applicable surface passes that criterion.

## Business Rules
Walk the requirement.md business rules; mark each Validated / Violated / N-A with evidence.
Call out any knowledge-base.md invariant verified here (e.g. no user enumeration, no partial session).

## Defects
Each failure: id, surface, the AC/business rule it breaks, severity, repro steps, expected vs actual.
```

### user-flow-test.md
The end-to-end user workflows walked, per surface.
```
---
unit: {unit-id}
intent: {intent-id}
created: {today}
updated: {today}
---

# UAT User-Flow Walkthroughs: {unit name} ({unit-id})

## Flows (per surface)
For each surface and each user flow (from ui-model.md / story.md): the ordered steps, the expected
behaviour at each step, the observed result, and PASS/FAIL. Note tooling used per surface.

## Cross-surface Consistency
Where the same flow runs on multiple surfaces, note any divergence in behaviour or copy
(security-relevant copy must stay consistent — e.g. generic invalid-credentials message).
```

### signoff.md
The final approval record.
```
---
unit: {unit-id}
intent: {intent-id}
uat-status: {pass | fail}
signed-off-by: {role / name — or "pending" until the gate}
created: {today}
updated: {today}
---

# UAT Sign-off: {unit name} ({unit-id})

## Summary
AC passed/total, surfaces exercised, open defects by severity.

## Decision
{ACCEPTED | REJECTED | ACCEPTED WITH FOLLOW-UPS} — with the conditions/follow-ups if any.

## Outstanding Items
Defects or business rules deferred, with owner and tracking reference.
```

## Sign-off Gate
If `checkpoint_mode` is `confirm` or `validate`:
Display the acceptance summary (AC pass/total per surface, open defects) and request approval:
```
sk.uat | Sign-off Gate  [checkpoint_mode: {mode}]

Surfaces exercised: {list}
Acceptance: {passed}/{total} criteria; defects: {by severity}
Business rules: {validated}/{total}

Type 'approved' to sign off UAT (uat-status = pass; test-status rolled up).
Type 'reject' to record UAT as failed with the open defects.
```
- On `approved`: set `06-uat/signoff.md` `uat-status: pass`, fill `signed-off-by`, and set the unit's
  story frontmatter `test-status = pass` ONLY if every applicable AC passed on every in-scope surface.
- On `reject`: `uat-status: fail`; leave/record story `test-status = fail` with the failing surfaces/AC.
- If `checkpoint_mode` is `autopilot`: roll up automatically (pass iff all applicable AC pass on all
  surfaces) and log it.

Note: `test-status` is the field sk.ship reads. If sk.test already set it, UAT may only move it to
`pass` when both contract/integration tests AND user acceptance pass; any UAT failure forces `fail`.

## Quality Bar
- Surfaces resolved from unit-brief.md and declared; correct tooling per surface (mobile never tested
  with browser tooling).
- Every acceptance criterion has a mapped result for every applicable surface; none left unmapped.
- Business rules from requirement.md each validated or flagged; knowledge-base invariants respected.
- The three flat artifacts written under `06-uat/` (acceptance-result.md, user-flow-test.md, signoff.md).
- UAT does not modify application code to pass a scenario — failures are recorded as defects.
- `test-status` rolls up honestly — `pass` only when all applicable AC pass on all in-scope surfaces.
