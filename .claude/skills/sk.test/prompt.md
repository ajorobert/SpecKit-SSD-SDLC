# sk.test
Generates and runs test suite for active story.
Role: backend (backend tests) | frontend (frontend tests)
Level: story

## Step 0: Capability Pack Selection
Load packs before generating tests.

1. Read session.yaml → get `role` and `active_story_id`
2. Read story frontmatter → check `tags`

**Role = backend**
- Always: `.claude/skills/csharp-clean-arch/SKILL.md`
- `db`, `schema` → `.claude/skills/postgresql-patterns/SKILL.md`
- `auth`, `keycloak` → `.claude/skills/auth-patterns/SKILL.md`
- `messaging`, `events` → `.claude/skills/messaging-patterns/SKILL.md`
- `cache`, `redis` → `.claude/skills/redis-patterns/SKILL.md`

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
