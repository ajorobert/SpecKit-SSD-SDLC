<!-- GENERIC LAYER — self-contained command -->
<!-- Before executing: read .generic/hooks/pre-command.md -->
<!-- After executing: read .generic/hooks/post-command.md -->
<!-- Context to load: see .generic/context-maps/command-context-map.md -->

# sk.review
Spec-aware code review: validates against bounded context, contracts, and ADRs.
Story-level command — requires active_story_id
Wraps: gstack /review

## Pre-flight
1. Read session.yaml active_story_id
   NULL → STOP: run sk.session focus --story {id} first

## Context loading
- specs/intents/{intent}/units/{unit}/architecture.md
- specs/intents/{intent}/units/{unit}/contracts/api-spec.json
- .specify/memory/architecture-decisions.md
- .specify/memory/standards/coding-standards.md
- .specify/memory/standards/observability-standards.md

## Context surface
Before invoking gstack /review, surface to agent:

"Reviewing story: {story-id} — {story title}
Bounded context: {unit name}. This unit owns: {entities/services from architecture.md}.
Must NOT cross into: {other units/services mentioned in architecture.md dependencies}
Contract: endpoints must match api-spec.json exactly — no undocumented changes.
ADR constraints: {applicable ADR summaries}

Pre-generation check: was existing code in the target area read before writing?
Flag if new abstractions were introduced that duplicate existing ones.

Module boundary checks (blocking):
- Method signatures changed from declared interface
- API response shape deviates from api-spec.json
- Untyped DTOs (any, raw maps, untyped dicts)
- Public method names don't describe intent (verb-noun)
- Direct access to another module's internal classes

Domain logic checks (findings):
- Business logic in a controller
- State change / DB write / external call outside injected interface
- Direct DB query outside a repository
- Command modifies more than one aggregate without going through domain events
- Function > 30 lines or > 1 logical operation
- Function > 3 parameters without a parameter object

Error handling: does code match the project's declared error handling pattern?

Observability (for stories adding new service endpoints):
- Structured JSON logging with trace_id and span_id present
- RED metrics instrumented (rate, errors, duration per endpoint)
- GET /health endpoint present and returning correct shape"

## Invoke
gstack /review

## Post-execution
Flag bounded context violations, endpoint deviations, ADR violations, and module boundary violations.
These must be resolved before the story proceeds to sk.verify.
Domain logic findings and observability gaps reported with severity from gstack /review output.
