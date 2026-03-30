# sk.implement
Executes implementation tasks for a story.
Role: backend | frontend | Level: story

## Input Artifacts
specs/knowledge-base.md (tier 1 — always read first)
specs/domains/{relevant-domain}/knowledge-base.md (tier 2 — if exists)
specs/intents/{intent}/units/{unit}/knowledge-base.md (tier 3 — if exists)

Note: knowledge bases contain non-derivable context only.
Read them before reading code. They explain why, not what.

specs/intents/{intent}/units/{unit}/stories/{story-id}/plan.md (required)
specs/intents/{intent}/units/{unit}/stories/{story-id}/tasks.md (required)
specs/intents/{intent}/units/{unit}/architecture.md
specs/intents/{intent}/units/{unit}/contracts/api-spec.json
.specify/memory/standards/coding-standards.md

## Steps
1. Verify plan.md and tasks.md exist
2. Set FEATURE_DIR to story directory
3. Execute upstream.implement from upstream-adapter.md in full
   Do not duplicate upstream logic
4. Flag any coding-standards.md violation immediately
   Do not proceed with that task until resolved

## Output Artifacts
src/{service}/** (backend role)
src/{frontend-surface}/** (frontend role)

## Quality Bar
- All tasks marked [X] on completion
- Tests written before implementation (TDD)
- No coding standards violations
- Implementation matches contracts/api-spec.json exactly
