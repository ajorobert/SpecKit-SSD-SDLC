# sk.test
Generates and runs test suite for active story.
Role: backend (backend tests) | frontend (frontend tests)
Level: story

## Step 0: Capability Pack Selection
Load packs before generating tests.

1. Read session.yaml → get `role` and `active_story_id`
2. Read story frontmatter → check `tags`

**Role = backend**
- Always (canonical SSOT): `.claude/skills/backend-architecture/SKILL.md`
- Always: `.claude/skills/backend-feature-patterns/SKILL.md`
- `persist`, `persistence`, `database`, `db`, `postgres`, `postgresql`, `ef core`, `dapper`, `migration`, `schema`, `jsonb`, `postgis`, `geo`, `transaction`, `repository`, `read model`, `projection`, `rls`, `tenant isolation`, `concurrency`, `xmin` → `.claude/skills/data-access-patterns/SKILL.md`
- `authorization`, `role`, `policy`, `rbac`, `abac`, `permission`, `user context`, `resource ownership`, `audit identity` → `.claude/skills/authorization-patterns/SKILL.md`
- `authentication`, `jwt`, `bearer`, `keycloak`, `oidc`, `claim`, `mfa`, `otp`, `m2m`, `claim mapping`, `composition root`, `wiring` → `.claude/skills/infrastructure-wiring/SKILL.md`
- `messaging`, `events`, `command`, `query`, `handler`, `publish`, `subscribe`, `outbox`, `saga`, `integration event`, `scheduled message`, `message bus` → `.claude/skills/orchestration-patterns/SKILL.md`
- `cache`, `caching`, `redis`, `hybrid cache`, `l1`, `l2`, `tag invalidation`, `distributed lock`, `rate limit`, `redlock`, `redis stream` → `.claude/skills/caching-patterns/SKILL.md`
- `adapter`, `integration adapter`, `external service adapter`, `vendor api`, `external integration`, `DelegatingHandler`, `chain order`, `M2M handler`, `typed httpclient`, `polly`, `resilience pipeline`, `resilience handler`, `port adapter split` → `.claude/skills/integration-adapter-patterns/SKILL.md`
- `feature flag`, `feature toggle`, `feature gate`, `rollout`, `gradual release`, `percentage rollout`, `a/b test`, `variant`, `gating`, `IFeatureManager`, `IFeatureManagerSnapshot`, `IVariantFeatureManager`, `sunset`, `flag cleanup` → `.claude/skills/feature-management-patterns/SKILL.md`

**Role = frontend**
- Always: `.claude/skills/accessibility-standards/SKILL.md`
- Portal: `.claude/skills/nextjs-patterns/SKILL.md`
- Admin: `.claude/skills/react-admin-patterns/SKILL.md`
- Mobile: `.claude/skills/react-native-patterns/SKILL.md`

List packs loaded before continuing.

## Input Artifacts
specs/intents/{intent}/units/{unit}/knowledge-base.md
  (tier 3 — invariants inform test design)

session.yaml (role determines test mode)
specs/intents/{intent}/units/{unit}/contracts/api-spec.json
specs/intents/{intent}/units/{unit}/contracts/test-plan.md
story-{ID}.md (acceptance criteria)
.specify/memory/standards/tech-stack.md (test framework)

## Steps

### If role = backend
1. Read contracts/test-plan.md provider section
2. Read api-spec.json — inventory all endpoints and error codes
3. [REFINE MODE] if provider tests exist, [CREATE MODE] if not
4. Generate provider contract tests:
   tests/contract/{unit}/provider/{endpoint}.provider.test.{ext}
   Coverage: happy path, validation error, auth rejection,
   not found, boundary values
5. Generate integration tests:
   tests/integration/{story-id}/{scenario}.integration.test.{ext}
6. Run tests — report results
7. Flag any endpoint in api-spec.json with no test coverage

### If role = frontend
1. Read contracts/test-plan.md consumer section
2. Read api-spec.json — identify fields frontend consumes
3. Read story acceptance criteria — map to E2E scenarios
4. [REFINE MODE] if consumer tests exist, [CREATE MODE] if not
5. Generate consumer contract tests:
   tests/contract/{unit}/consumer/{endpoint}.consumer.test.{ext}
   Mock backend using api-spec.json responses
6. Generate E2E tests mapped to acceptance criteria:
   tests/e2e/{story-id}/{acceptance-criterion}.e2e.test.{ext}
7. Generate component tests:
   tests/components/{unit}/{component}.test.{ext}
8. Run tests — report results
9. Flag any acceptance criterion with no E2E test coverage

### If role = neither
STOP: "sk.test requires backend or frontend role.
Run sk.session switch --role backend or frontend"

## Output Artifacts
tests/contract/{unit}/provider/ (backend)
tests/integration/{story-id}/ (backend)
tests/contract/{unit}/consumer/ (frontend)
tests/e2e/{story-id}/ (frontend)
tests/components/{unit}/ (frontend)

## Quality Bar
- Every endpoint has provider test (backend)
- Every acceptance criterion has E2E test (frontend)
- Tests runnable without manual setup
- Test names describe scenarios not implementation
- Coverage report generated and displayed

## Completion Signal
Last line of output must be exactly one of:
`SK_RESULT: PASS` — all tests passed
`SK_RESULT: FAIL` — one or more tests failed
