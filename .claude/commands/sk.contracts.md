# sk.contracts
Defines API contracts and generates provider tests for a unit.
Role: architect | Level: unit

## Input Artifacts
specs/intents/{intent}/units/{unit}/architecture.md
specs/intents/{intent}/units/{unit}/data-model.md
.specify/memory/service-registry.md
.specify/memory/standards/api-standards.md
.specify/memory/standards/tech-stack.md (for test framework)

## Steps
1. [REFINE MODE] if contracts/ exists, [CREATE MODE] if not
2. Check service-registry.md — no breaking changes without confirmation
3. Design endpoints following api-standards.md
4. Write OpenAPI spec
5. Write test plan (provider + consumer sections)
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
- Test plan has both provider and consumer sections
- Provider tests cover happy path + error cases + auth rejection
- No undocumented breaking changes
