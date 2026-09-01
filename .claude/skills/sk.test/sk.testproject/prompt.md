# sk.testproject
Generates and runs the test suite for ONE impacted project of a unit.
Role: backend | frontend | mobile (from the project type) | Level: project

Internal sub-skill — invoked by the sk.test orchestrator, once per impacted project.
Do not invoke directly.

## What "one project" means
A unit may impact several projects (MarketPlace.API, MarketPlace.Customer.Web, MarketPlace.Admin.Web, MarketPlace.Mobile …).
This sub-skill tests exactly ONE of them, named `{Project}` with code root `{CodeRoot}`. It generates
and runs the tests that verify that project's slice of the unit. It does NOT test the other projects.

The orchestrator passes the target project as `{Project}` / `{CodeRoot}` / `{ProjectType}` and the
effective `--role`, resolved from `unit-brief.md` → Impacted Projects.

## Step 0: Capability Pack Selection
Load packs before generating tests. Read session.yaml and the unit's stories for `tags`.

**ProjectType = Backend** (role backend)
- Always: `.claude/skills/backend-feature-patterns/SKILL.md`
- `persist`, `persistence`, `database`, `db`, `postgres`, `postgresql`, `ef core`, `dapper`, `migration`, `schema`, `jsonb`, `postgis`, `geo`, `transaction`, `repository`, `read model`, `projection`, `rls`, `tenant isolation`, `concurrency`, `xmin` → `.claude/skills/data-access-patterns/SKILL.md`
- `auth`, `authentication`, `authorization`, `jwt`, `bearer`, `keycloak`, `oidc`, `role`, `policy`, `claim`, `mfa`, `otp`, `m2m`, `user context`, `idempotency` → `.claude/skills/authorization-patterns/SKILL.md`
- `messaging`, `events`, `command`, `query`, `handler`, `publish`, `subscribe`, `outbox`, `saga`, `integration event`, `scheduled message`, `message bus` → `.claude/skills/orchestration-patterns/SKILL.md`
- `cache`, `caching`, `redis`, `hybrid cache`, `l1`, `l2`, `tag invalidation`, `distributed lock`, `rate limit`, `redlock`, `redis stream` → `.claude/skills/caching-patterns/SKILL.md`
- `adapter`, `integration adapter`, `external service adapter`, `vendor api`, `external integration`, `DelegatingHandler`, `chain order`, `M2M handler`, `typed httpclient`, `polly`, `resilience pipeline`, `resilience handler`, `port adapter split` → `.claude/skills/integration-adapter-patterns/SKILL.md`
- `feature flag`, `feature toggle`, `feature gate`, `rollout`, `gradual release`, `percentage rollout`, `a/b test`, `variant`, `gating`, `IFeatureManager`, `IFeatureManagerSnapshot`, `IVariantFeatureManager`, `sunset`, `flag cleanup` → `.claude/skills/feature-management-patterns/SKILL.md`

**ProjectType = Frontend / Mobile** (role frontend | mobile)
Do NOT hardcode a per-surface pack list — resolve via the shared preamble so
tests load the same packs the code was generated and reviewed under:
1. Read `.claude/skills/shared/surface-resolution.md`.
2. It maps `{ProjectType}` + `{Project}` → surface, then loads that surface's
   **Always-load skill packs** from `.specify/memory/projects/{surface}/project.md`.
   `admin` = `nextjs-patterns` + `nextjs-admin-patterns` (both Next.js; no
   `react-admin-patterns`). Mobile does not load `frontend-design-system`.

List the packs loaded before continuing.

## Input Artifacts
Resolve `UNIT_DIR = specs/intents/{intent}/units/{unit}/`, `DESIGN_DIR = UNIT_DIR/02-design/`,
`IMPL_DIR = UNIT_DIR/04-implementation/{Project}/`, `TEST_DIR = UNIT_DIR/05-test/{Project}/`.

- DESIGN_DIR/contracts/test-plan.md                  (provider/consumer test plan — primary source)
- DESIGN_DIR/contracts/api-spec.json                 (canonical machine API contract)
- DESIGN_DIR/projects/{Project}.md                   (if exists — the per-project design slice)
- DESIGN_DIR/architecture.md                         (system architecture)
- DESIGN_DIR/database-design.md                      (if exists — DB/data model; Backend)
- DESIGN_DIR/ui-model.md                             (if exists — REQUIRED for Frontend/Mobile)
- UNIT_DIR/03-plan/{Project}/plan.md                 (if exists — its Test Plan section)
- IMPL_DIR/implementation.md, validation.md          (if exists — what was actually built)
- UNIT_DIR/01-story/ story.md, requirement.md, acceptance-criteria.md  (the unit's stories)
- UNIT_DIR/knowledge-base.md                         (if exists — tier 3 invariants inform test design)
- .specify/memory/standards/tech-stack.md            (test framework + coverage thresholds)
- .specify/memory/standards/coding-standards.md

## Pre-flight
1. Verify the target `{Project}` appears in `unit-brief.md` → Impacted Projects (with `{CodeRoot}`).
   Missing: STOP — report "Project {Project} is not an impacted project of this unit."
2. Verify DESIGN_DIR/contracts/test-plan.md exists (or api-spec.json).
   Missing: WARN — proceed against acceptance criteria only, and flag the contract gap.
3. For a Frontend or Mobile project, verify DESIGN_DIR/ui-model.md exists.
   Missing: WARN — proceed, but flag that the component plan is unanchored.
4. Determine execution mode:
   - **REFINE** if the orchestrator passed REFINE, OR `TEST_DIR` exists with documented failing cases —
     repair/regenerate only the failing tests; keep passing ones.
   - **RESUME** if `TEST_DIR` exists with open (unwritten) cases — continue from the first open case.
   - **CREATE** otherwise — full suite.

## Output Layout
Two destinations — keep them distinct:
- **Runnable tests** are written inside the project's test tree under `{CodeRoot}` (e.g.
  `tests/contract/{unit}/provider/`, `tests/integration/{story-id}/`, `tests/components/{unit}/`,
  `tests/e2e/{story-id}/`). Never write runnable tests under `05-test/`.
- **Test-design / tracking docs** are written under `UNIT_DIR/05-test/{Project}/`:

**Backend project:**
```
05-test/{Project}/
├── unit-test.md         # unit-level cases (handlers, mappers, validators, claim projection) + expected results
├── integration-test.md  # service + database/pipeline integration cases + expected results
└── contract-test.md     # PROVIDER contracts: every endpoint in api-spec.json + regression checks
```

**Frontend / Mobile project:**
```
05-test/{Project}/
├── component-test.md     # component / UI / screen cases + expected results (a11y where applicable)
└── contract-test.md      # CONSUMER contracts: endpoints/claims/session fields this surface depends on + regression checks
```

`{Project}` is the exact project name from the Impacted Projects table (e.g. `MarketPlace.API`,
`MarketPlace.Customer.Web`). Do NOT invent or abbreviate it.

## Execution

### 1. Scope the project slice
Read `02-design/projects/{Project}.md` (if present), `02-design/contracts/test-plan.md`, and
`04-implementation/{Project}/` first — they define what THIS project owns and what was actually built.
Everything tested MUST stay inside this slice — do not write tests for behaviour another project owns,
and do not invent endpoints/claims not in the contract.

### 2A. Backend — generate the three docs + runnable tests
Read `test-plan.md` → Provider section and `api-spec.json` (inventory every endpoint + error code).

- **unit-test.md** — unit cases for the handlers, mappers, validators, and claim/identity projection
  the project implements. Each case: id, scenario, given, expected result. Cover happy path, validation
  errors, boundary values, and any invariant from knowledge-base.md. Map cases to the code under test.
- **integration-test.md** — service + database / request-pipeline integration cases (e.g. middleware
  chain, EF Core + Dapper paths, outbox/saga where applicable). Each case: id, scenario, given,
  expected result. State explicitly which cases are **N/A by construction** (e.g. no mutation
  endpoints → no idempotency-replay/outbox cases) with the reason, per test-plan.md.
- **contract-test.md** — PROVIDER contract: one row per endpoint in api-spec.json (happy path, auth
  rejection 401, authorization rejection 403, validation error, not-found, boundary), plus negative /
  anti-fabrication assertions (routes that must NOT exist). End with a **Regression checks** section:
  the existing behaviour that must keep passing after this change.

Then write the runnable tests under `{CodeRoot}`:
- Provider contract tests: `tests/contract/{unit}/provider/{endpoint}.provider.test.{ext}`
- Integration tests: `tests/integration/{story-id}/{scenario}.integration.test.{ext}`
- Unit tests: alongside the project's existing unit-test layout (per coding-standards.md).

### 2B. Frontend / Mobile — generate the two docs + runnable tests
Read `test-plan.md` → Consumer section for this surface (web / admin / mobile) and `api-spec.json`
(identify the fields/claims this surface consumes).

- **component-test.md** — component / screen / UI cases mapped to acceptance criteria: rendering,
  state, form behaviour, error/empty/loading states, and accessibility expectations (per
  accessibility-standards). Each case: id, scenario, given, expected result, AC mapped.
- **contract-test.md** — CONSUMER contract: the endpoints, claims, and session fields this surface
  depends on (each confirmed present in api-spec.json — never invent one), the mocked backend responses
  used, and error-handling expectations (generic non-enumerating copy, 401 handling, no partial
  session). End with a **Regression checks** section.

Then write the runnable tests under `{CodeRoot}`:
- Consumer contract tests: `tests/contract/{unit}/consumer/{endpoint}.consumer.test.{ext}` (mock backend
  from api-spec.json responses).
- Component tests: `tests/components/{unit}/{component}.test.{ext}`.
- E2E mapped to acceptance criteria (if the platform runs E2E here rather than in sk.uat):
  `tests/e2e/{story-id}/{acceptance-criterion}.e2e.test.{ext}`.

### 3. Run the suite
Run the project's tests. Record pass/fail per case in the relevant doc. Flag any endpoint in
api-spec.json with no provider/consumer test, and any acceptance criterion with no mapped test.

### 4. Roll up
At the bottom of each doc, record the suite result (cases written, green/red, coverage vs
tech-stack.md threshold). Report the project's overall PASS/FAIL to the orchestrator.

## Doc front-matter
Every doc under `05-test/{Project}/` starts with:
```
---
project: {Project}
project_type: {Backend | Frontend | Mobile}
code_root: {CodeRoot}
unit: {unit-id}
intent: {intent-id}
role: {backend | frontend | mobile}
created: {today}
updated: {today}
---
```

## IMPORTANT Test Rules (enforced)
- Do NOT modify the implementation under test to make a test pass — tests verify behaviour, they do not
  reshape it. A genuine defect is reported as a finding, not patched here.
- MUST inspect the existing test tree before adding — match the established framework, layout, and
  fixtures (per tech-stack.md / coding-standards.md). Do not rewrite passing tests.
- Tests must run without manual setup; test names describe scenarios, not implementation.
- Never invent an endpoint, claim, or field that is not in api-spec.json.
- No skipped / pending tests (`.skip`, `xit`, `it.only`, `fdescribe`) without a documented reason.

## Quality Bar
- Tests exactly ONE project; writes runnable tests only within `{CodeRoot}`; writes docs only within
  `05-test/{Project}/`.
- Stays inside the project's design/contract slice — no behaviour belonging to another project.
- Backend: every endpoint in api-spec.json has a provider contract test; integration cases cover
  service+DB/pipeline; unit cases cover handlers/mappers/validators; N/A cases are justified.
- Frontend/Mobile: every consumed endpoint/claim has a consumer contract test (all present in the
  contract); component cases map to acceptance criteria; accessibility covered.
- Provider contracts (backend) and consumer contracts (frontend/mobile) agree — consumers expect only
  what the provider contract guarantees.
- Regression checks present in every contract doc; coverage threshold per tech-stack.md met.
- All required test docs written for the project type (Backend: 3; Frontend/Mobile: 2).
