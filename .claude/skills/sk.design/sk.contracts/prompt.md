# sk.contracts
Defines API contracts and generates provider tests for a unit.
Role: architect | Level: unit

Internal sub-skill — invoked by sk.design. Do not invoke directly.

## Design Output Layout
All design artifacts live under `specs/intents/{intent}/units/{unit}/02-design/`.
This sub-skill writes the machine contract artifacts to `02-design/contracts/`
(`api-spec.json` stays the canonical OpenAPI source), the human-readable
`02-design/api-contract.md`, and one backend design page per impacted Backend project
under `02-design/projects/`.

## Input Artifacts
specs/intents/{intent}/units/{unit}/unit-brief.md (Impacted Projects table)
specs/intents/{intent}/units/{unit}/02-design/architecture.md
specs/intents/{intent}/units/{unit}/02-design/database-design.md
.specify/memory/service-registry.md
.specify/memory/standards/api-standards.md
.specify/memory/standards/tech-stack.md (for test framework)
.claude/skills/design-principles/SKILL.md

## Project-Scoped Mode (`--project {ProjectName …}`)
sk.design PROJECT mode — write ONLY `02-design/projects/{ProjectName}.md` for the named Backend
projects; steps 1–8 do not run and none of this skill's other outputs (provider tests,
test-plan.md, README.md, service-registry.md) are written. Shared artifacts (api-spec.json,
api-contract.md, architecture.md, database-design.md) are read-only inputs; if one is missing,
derive that slice from the unit stories + unit-brief.md and record the gap under the page's
Open Questions. A named project with no backend impact: report it and skip the file — never an
empty page, never a page for an unnamed project.

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
8. Write the human-readable `02-design/api-contract.md` from `templates/artifacts/api-contract-template.md`.
   It is a companion to `contracts/api-spec.json` (the canonical OpenAPI source) — keep the two in sync;
   never document an endpoint here that is absent from api-spec.json.
9. Write one backend design page per impacted Backend project:
   - Read `unit-brief.md` → Impacted Projects; for each row with Type = Backend, write
     `02-design/projects/{ProjectName}.md` using `templates/artifacts/project-design-template.md`.
   - File name = the project name from unit-brief.md (e.g. `MarketPlace.API.md`) — dynamic, not fixed.
   - The page is a VIEW that synthesises the project-relevant slice of architecture.md,
     database-design.md, and api-contract.md (endpoints owned, handlers, entities, security,
     consistency/outbox per write path). It references the canonical docs; it does not redefine them.
   - Frontend/Mobile project pages are NOT written here — sk.ui-design owns those.

## Output Artifacts
specs/intents/{intent}/units/{unit}/02-design/contracts/api-spec.json
specs/intents/{intent}/units/{unit}/02-design/contracts/test-plan.md
specs/intents/{intent}/units/{unit}/02-design/contracts/README.md
specs/intents/{intent}/units/{unit}/02-design/api-contract.md
specs/intents/{intent}/units/{unit}/02-design/projects/{BackendProject}.md (one per impacted Backend project)
tests/contract/{unit}/provider/{endpoint}.provider.test.{ext}
.specify/memory/service-registry.md (updated)

## Quality Bar
- Machine artifacts written under `02-design/contracts/`; `api-contract.md` written at `02-design/` root
- api-contract.md documents only endpoints present in contracts/api-spec.json (the two stay in sync)
- One `02-design/projects/{ProjectName}.md` written for every impacted Backend project, named from unit-brief.md
- All endpoints follow api-standards.md URL and response format
- Test plan has provider section and at least one per-consumer section
- Per-consumer sections list only the endpoints that consumer actually calls
- Provider tests cover happy path + error cases + auth rejection
- No undocumented breaking changes
- Idempotency-Key declared on all mutation endpoints (POST/PUT/PATCH/DELETE)
- Dedup Strategy declared for every consumed event with Idempotent Handler = yes
- Outbox column filled for every published event where handler also writes state
- commandId field present in command schema for any command dispatched async
