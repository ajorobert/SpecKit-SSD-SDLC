# sk.plan-eng-review
Validates engineering plan against existing service boundaries, domain model, and ADRs.
Role: architect | Level: unit
Wraps: gstack /plan-eng-review

## Pre-flight
1. Read session.yaml active_unit_id
   NULL → STOP: run sk.session focus --unit {unit-id} first
2. Verify role = architect in session.yaml
   Other role → note mismatch; this command is most effective with architect role

## Context loading
- specs/intents/{intent}/units/{unit}/architecture.md (required)
- .specify/memory/service-registry.md — existing service boundaries
- .specify/memory/domain-model.md — existing domain entities
- .specify/memory/architecture-decisions.md — ADR constraints
- specs/intents/{intent}/units/{unit}/stories/ — stories in scope

## Context surface
Before invoking gstack /plan-eng-review, surface to agent:

"Reviewing engineering plan for unit: {unit name}
Existing service boundaries: {relevant entries from service-registry.md}
Domain entities already owned: {relevant entities from domain-model.md}
ADR constraints in effect: {applicable ADR summaries}
Review against: no new service boundary violations, no entity ownership conflicts, no ADR contradictions."

## Invoke
gstack /plan-eng-review

## Post-execution
Flag any finding that:
- Contradicts an existing service boundary in service-registry.md
- Introduces entity ownership conflicts with domain-model.md
- Violates an ADR decision

If a new cross-service decision is introduced:
- Suggest creating an ADR via sk.adr

## Quality Bar
- No service boundary violations
- No domain entity ownership conflicts
- No ADR constraint violations
- ADR suggested for any new cross-service architectural decision
