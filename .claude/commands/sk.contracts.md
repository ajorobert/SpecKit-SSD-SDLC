# sk.contracts
Defines API contracts and generates provider tests for a unit.
Role: architect | Level: unit

## Input Artifacts
specs/intents/{intent}/units/{unit}/architecture.md
specs/intents/{intent}/units/{unit}/data-model.md
.specify/memory/service-registry.md
.specify/memory/standards/api-standards.md
.specify/memory/standards/tech-stack.md (for test framework)
.claude/skills/design-principles/SKILL.md

## Steps
1. [REFINE MODE] if contracts/ exists, [CREATE MODE] if not
2. Check service-registry.md — no breaking changes without confirmation
3. Design endpoints following api-standards.md
4. Write OpenAPI spec
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
specs/intents/{intent}/units/{unit}/contracts/api-spec.json
specs/intents/{intent}/units/{unit}/contracts/test-plan.md
specs/intents/{intent}/units/{unit}/contracts/README.md
tests/contract/{unit}/provider/{endpoint}.provider.test.{ext}
.specify/memory/service-registry.md (updated)

## Quality Bar
- All endpoints follow api-standards.md URL and response format
- Test plan has provider section and at least one per-consumer section
- Per-consumer sections list only the endpoints that consumer actually calls
- Provider tests cover happy path + error cases + auth rejection
- No undocumented breaking changes
- Idempotency-Key declared on all mutation endpoints (POST/PUT/PATCH/DELETE)
