# sk.review
Spec-aware code review: validates against bounded context, contracts, and ADRs.
Role: backend, frontend | Level: story
Wraps: gstack /review

## Pre-flight
1. Read session.yaml active_story_id
   NULL → STOP: run sk.session focus --story {id} first

## Context loading
- specs/intents/{intent}/units/{unit}/architecture.md — bounded context, module boundaries, owned entities
- specs/intents/{intent}/units/{unit}/contracts/api-spec.json — endpoint signatures
- .specify/memory/architecture-decisions.md — ADR constraints
- .specify/memory/standards/coding-standards.md — coding conventions

## Context surface
Before invoking gstack /review, surface to agent:

"Reviewing story: {story-id} — {story title}
Bounded context: {unit name}. This unit owns: {entities/services from architecture.md}.
Must NOT cross into: {other units/services mentioned in architecture.md dependencies}
Contract: endpoints must match api-spec.json exactly — no undocumented changes.
ADR constraints: {applicable ADR summaries}
Coding standards: {key rules from coding-standards.md}"

## Invoke
gstack /review

## Post-execution
Flag any finding that:
- Violates bounded context boundaries (accessing another unit's internals directly)
- Deviates from api-spec.json endpoint signatures
- Contradicts an ADR decision

Bounded context and ADR violations must be resolved before story can proceed to sk.verify.
Other findings follow gstack /review severity classification.

## Quality Bar
- No bounded context violations
- No endpoint signature deviations from api-spec.json
- No ADR constraint violations
- All other findings reported with gstack /review output
