# sk.contracts
Defines API contracts and generates provider tests for a unit.
Role: architect | Level: unit

Internal sub-skill — invoked by sk.design. Do not invoke directly.

## Path Resolution (per story-lifecycle.md §3)
Resolve `STORY_DIR` from session.yaml `story_dir`. Contracts are written to `STORY_DIR/02-design/`.
The machine-readable OpenAPI spec is `02-design/api-spec.json` (canonical source of truth for
endpoints) with the human-readable summary `02-design/api-contract.md`. Legacy fallback (no
story_dir): the `contracts/` subfolder under the unit path.

## Input Artifacts
STORY_DIR/02-design/architecture.md   (legacy fallback: specs/intents/{intent}/units/{unit}/architecture.md)
STORY_DIR/02-design/database-design.md (legacy fallback: .../data-model.md)
.specify/memory/service-registry.md
.specify/memory/standards/api-standards.md
.specify/memory/standards/tech-stack.md (for test framework)
.claude/skills/design-principles/SKILL.md

## Steps
1. [REFINE MODE] if contracts/ exists, [CREATE MODE] if not
2. Check service-registry.md — no breaking changes without confirmation
3. Design endpoints following api-standards.md
4. Write OpenAPI spec → `STORY_DIR/02-design/api-spec.json` (machine contract, source of truth),
   plus a human-readable `STORY_DIR/02-design/api-contract.md` summarizing endpoints, request/
   response shapes, and error codes. Keep the two in sync.
5. Write test plan with the following structure:
   ```
   ## Provider Tests
   {endpoint-by-endpoint: happy path, validation error, auth rejection, not found, boundary values}

   ## Consumer Tests

   ### web (Next.js)
   {endpoints this consumer calls, response fields it depends on,
    pageSize/pagination expectations, error handling expectations}

   ### mobile (React Native)
   {endpoints this consumer calls, offline/retry scenarios,
    response size constraints, any mobile-specific error handling}

   ### admin (React Admin)
   {endpoints this consumer calls, bulk operation endpoints,
    full result set vs paginated expectations, role-based endpoint access}
   ```
   For each consumer: only list endpoints that consumer actually calls.
   If a consumer does not exist for this project, omit that section.
6. Generate provider contract tests in correct framework per tech-stack.md
7. If REFINE: never remove existing endpoints
   breaking change → add versioned endpoint, flag to user

## Output Artifacts
STORY_DIR/02-design/api-spec.json     (machine contract — source of truth)
STORY_DIR/02-design/api-contract.md   (human-readable summary)
STORY_DIR/02-design/test-plan.md
tests/contract/{ProjectName}/provider/{endpoint}.provider.test.{ext}
.specify/memory/service-registry.md (updated)
(Legacy fallback: specs/intents/{intent}/units/{unit}/contracts/{api-spec.json,test-plan.md,README.md})

## Quality Bar
- All endpoints follow api-standards.md URL and response format
- Test plan has provider section and at least one per-consumer section
- Per-consumer sections list only the endpoints that consumer actually calls
- Provider tests cover happy path + error cases + auth rejection
- No undocumented breaking changes
- Idempotency-Key declared on all mutation endpoints (POST/PUT/PATCH/DELETE)
- Dedup Strategy declared for every consumed event with Idempotent Handler = yes
- Outbox column filled for every published event where handler also writes state
- commandId field present in command schema for any command dispatched async
