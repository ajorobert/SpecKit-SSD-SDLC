<!-- GENERIC LAYER — self-contained command -->
<!-- Before executing: read .generic/hooks/pre-command.md -->
<!-- After executing: read .generic/hooks/post-command.md -->
<!-- Context to load: see .generic/context-maps/command-context-map.md -->

# sk.test
Generates and runs test suite for active story.
Role: backend-qa (backend tests) | frontend-qa (frontend tests)
Level: story

## Pre-flight
1. Read session.yaml active_story_id and role
   NULL story → STOP: run sk.session focus --story {id} first
   role = neither backend-qa nor frontend-qa → STOP:
     "sk.test requires backend-qa or frontend-qa role.
      Run sk.session switch --role backend-qa or frontend-qa"
2. Read story-{ID}.md frontmatter — verify status = in-progress or review
3. Load context:
   - specs/intents/{intent}/units/{unit}/contracts/api-spec.json
   - specs/intents/{intent}/units/{unit}/contracts/test-plan.md
   - .specify/memory/standards/tech-stack.md
   - .specify/memory/standards/coding-standards.md (Test Coverage Thresholds)

## Mode detection
- tests/contract/{unit}/provider/ exists → [REFINE MODE]
- tests/contract/{unit}/provider/ missing → [CREATE MODE]
Declare mode at start of execution.

## If role = backend-qa

### Step 1 — Read test-plan.md provider section
Inventory: endpoints to test, edge cases, integration scenarios, test data.

### Step 2 — Read api-spec.json
Inventory all endpoints, parameters, response shapes, error codes.

### Step 3 — Generate provider contract tests
Path: tests/contract/{unit}/provider/{endpoint}.provider.test.{ext}

Each endpoint test must cover:
- Happy path: valid request → expected response shape and status
- Validation error: invalid/missing fields → 400 with error details
- Auth rejection: missing/expired/wrong-scope token → 401 or 403
- Not found: unknown resource ID → 404
- Boundary values: min/max values, empty strings, null fields

### Step 4 — Generate integration tests
Path: tests/integration/{story-id}/{scenario}.integration.test.{ext}

Cover: service + database interactions, migration side effects,
concurrent request scenarios from test-plan.md.

### Step 5 — Run tests
Execute full test suite. Report:
- Pass/fail count per file
- Coverage percentage per threshold category
- Any endpoint in api-spec.json with no test coverage (flag as gap)

### Step 6 — Update story
Update story-{ID}.md:
  test-status: pass (all pass) | fail (any failure)
  status: testing (if not already security-review or done)

## If role = frontend-qa

### Step 1 — Read test-plan.md consumer section
Inventory: fields consumed per endpoint, UI scenarios, error states,
accessibility scenarios.

### Step 2 — Read api-spec.json
Identify all fields frontend consumes per endpoint.

### Step 3 — Generate consumer contract tests
Path: tests/contract/{unit}/consumer/{endpoint}.consumer.test.{ext}

Mock backend responses using api-spec.json response shapes.
Verify frontend consumes only declared fields.
Test error response handling: 400, 401, 403, 404, 500.

### Step 4 — Generate E2E tests
Path: tests/e2e/{story-id}/{acceptance-criterion}.e2e.test.{ext}

Map one test file per acceptance criterion from story-{ID}.md.
Test names describe the user scenario not the implementation.
Cover: happy path, error state, loading state.

### Step 5 — Generate component tests
Path: tests/components/{unit}/{component}.test.{ext}

Cover: prop variants, user events, conditional renders, accessibility
(keyboard navigation, ARIA roles, screen reader labels).

### Step 6 — Run tests
Execute full test suite. Report:
- Pass/fail count per file
- Coverage percentage per threshold category
- Any acceptance criterion with no E2E test (flag as gap)

### Step 7 — Update story
Update story-{ID}.md:
  test-status: pass (all pass) | fail (any failure)
  status: testing (if not already security-review or done)

## Quality Bar
- Every endpoint has provider test (backend-qa)
- Every acceptance criterion has E2E test (frontend-qa)
- Tests runnable without manual setup
- Test names describe scenarios not implementation
- Coverage report generated and displayed
- No skipped tests without documented reason
