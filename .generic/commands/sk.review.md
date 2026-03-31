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

## Invoke
Surface bounded context, contract constraints, and ADRs to agent, then invoke gstack /review

## Post-execution
Flag bounded context violations, endpoint deviations, and ADR violations.
These must be resolved before the story proceeds to sk.verify.
