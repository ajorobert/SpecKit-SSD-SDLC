# sk.test
Generates and runs the test suite for the active story, **project-scoped**.
Role: backend (backend tests) | frontend (frontend tests)
Level: story

## Invocation
- `sk.test --project {ProjectName}`   — test one project (recommended)
- `sk.test`                           — test all implemented projects matching the session role

## Step 0: Capability Pack Selection
Load packs before generating tests.

1. Read session.yaml → get `role`; resolve the active story via
   `.specify/memory/standards/story-lifecycle.md` §3 (`unit_dir`). Resolve the target
   project(s) per §4: `--project {ProjectName}` or every project under
   `UNIT_DIR/04-implementation/{ProjectName}/` matching the role. Read the project's `type`
   from `.specify/memory/projects/index.md` — it selects which test files this phase emits.
2. Read `UNIT_DIR/stories/<story-file>` frontmatter → check `tags`

**Role = backend**
- Always: `.claude/skills/backend-feature-patterns/SKILL.md`
- `persist`, `persistence`, `database`, `db`, `postgres`, `postgresql`, `ef core`, `dapper`, `migration`, `schema`, `jsonb`, `postgis`, `geo`, `transaction`, `repository`, `read model`, `projection`, `rls`, `tenant isolation`, `concurrency`, `xmin` → `.claude/skills/persistence-patterns/SKILL.md`
- `auth`, `authentication`, `authorization`, `jwt`, `bearer`, `keycloak`, `oidc`, `role`, `policy`, `claim`, `mfa`, `otp`, `m2m`, `user context`, `idempotency` → `.claude/skills/keycloak-patterns/SKILL.md`
- `messaging`, `events`, `command`, `query`, `handler`, `publish`, `subscribe`, `outbox`, `saga`, `integration event`, `scheduled message`, `message bus` → `.claude/skills/wolverine-patterns/SKILL.md`
- `cache`, `caching`, `redis`, `hybrid cache`, `l1`, `l2`, `tag invalidation`, `distributed lock`, `rate limit`, `redlock`, `redis stream` → `.claude/skills/hybridcache-patterns/SKILL.md`
- `adapter`, `integration adapter`, `external service adapter`, `vendor api`, `external integration`, `DelegatingHandler`, `chain order`, `M2M handler`, `typed httpclient`, `polly`, `resilience pipeline`, `resilience handler`, `port adapter split` → `.claude/skills/integration-adapter-patterns/SKILL.md`
- `feature flag`, `feature toggle`, `feature gate`, `rollout`, `gradual release`, `percentage rollout`, `a/b test`, `variant`, `gating`, `IFeatureManager`, `IFeatureManagerSnapshot`, `IVariantFeatureManager`, `sunset`, `flag cleanup` → `.claude/skills/feature-management-patterns/SKILL.md`

**Role = frontend**
- Always: `.claude/skills/accessibility-standards/SKILL.md`
- Portal: `.claude/skills/nextjs-patterns/SKILL.md`
- Admin: `.claude/skills/react-admin-patterns/SKILL.md`
- Mobile: `.claude/skills/react-native-patterns/SKILL.md`

List packs loaded before continuing.

## Input Artifacts
UNIT_DIR/stories/ (acceptance criteria in the story files)   (each criterion → at least one test)
UNIT_DIR/stories/ (requirements in the story files)           (business rules, NFRs)
UNIT_DIR/02-design/api-contract.md         (+ api-spec.json if present — endpoints/errors)
UNIT_DIR/02-design/projects/{ProjectName}.md  (integration points, regression risks)
UNIT_DIR/04-implementation/{ProjectName}/implementation.md  (what was built)
.specify/memory/projects/{ProjectName}/tech-stack.md  (test framework for this project)
.specify/memory/standards/tech-stack.md     (shared fallback)
(Backward compat: legacy `specs/intents/**/contracts/*` + `story-{ID}.md` read in place if present.)

## Test Documentation Output (per story-lifecycle.md §2)
Alongside the runnable test code, write per-project markdown deliverables under
`UNIT_DIR/05-test/{ProjectName}/` (create if absent, update in place per §7). The files depend
on the project `type`:

- **backend / library** → `unit-test.md`, `integration-test.md`, `contract-test.md`
- **frontend / mobile** → `component-test.md`, `contract-test.md`

Each file documents: what it validates (business rules / API contracts / integration behavior /
regression risks), the scenarios covered, the runnable test files generated, and pass/fail
results. These docs are the human-readable record; the actual tests live in the project's test tree.

## Steps

### If project type = backend / library
1. Read `02-design/api-contract.md` (+ api-spec.json) — inventory endpoints and error codes.
2. [REFINE MODE] if tests exist, [CREATE MODE] if not.
3. **unit tests** → validate business rules from `requirement.md`. Document in `05-test/{ProjectName}/unit-test.md`.
4. **integration tests** → validate integration behavior + regression risks. Code:
   `tests/integration/{story-id}/{scenario}.integration.test.{ext}`. Document in `integration-test.md`.
5. **contract tests** → provider contract per endpoint:
   `tests/contract/{ProjectName}/provider/{endpoint}.provider.test.{ext}` (happy path, validation
   error, auth rejection, not found, boundary). Document in `contract-test.md`.
6. Run tests — record results in each doc.
7. Flag any endpoint or business rule with no coverage.

### If project type = frontend / mobile
1. Read `02-design/api-contract.md` — identify fields the frontend consumes.
2. Read `stories/ (acceptance criteria in the story files)` — map criteria to scenarios.
3. [REFINE MODE] if tests exist, [CREATE MODE] if not.
4. **component tests** → component behavior/rendering:
   `tests/components/{ProjectName}/{component}.test.{ext}`. Document in `05-test/{ProjectName}/component-test.md`.
5. **contract tests** → consumer contract, mocking the backend from the api-contract:
   `tests/contract/{ProjectName}/consumer/{endpoint}.consumer.test.{ext}`. Document in `contract-test.md`.
6. Run tests — record results in each doc.
7. Flag any acceptance criterion or consumed field with no coverage.

### If role = neither
STOP: "sk.test requires backend or frontend role.
Run sk.session switch --role backend or frontend"

## Output Artifacts
UNIT_DIR/05-test/{ProjectName}/   — markdown docs (per project type, see above)
tests/contract/{ProjectName}/provider/   (backend/library)
tests/integration/{story-id}/            (backend/library)
tests/contract/{ProjectName}/consumer/   (frontend/mobile)
tests/components/{ProjectName}/          (frontend/mobile)

## Quality Bar
- Every endpoint has a provider contract test (backend/library)
- Every acceptance criterion maps to at least one test (frontend/mobile)
- Business rules, API contracts, integration behavior, and regression risks each documented
- Tests runnable without manual setup
- Test names describe scenarios not implementation
- Coverage report generated and displayed
- 05-test/{ProjectName}/ docs written for the project's type

## Completion Signal
Last line of output must be exactly one of:
`SK_RESULT: PASS` — all tests passed
`SK_RESULT: FAIL` — one or more tests failed
