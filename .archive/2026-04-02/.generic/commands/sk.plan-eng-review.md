<!-- GENERIC LAYER — self-contained command -->
<!-- Before executing: read .generic/hooks/pre-command.md -->
<!-- After executing: read .generic/hooks/post-command.md -->
<!-- Context to load: see .generic/context-maps/command-context-map.md -->

# sk.plan-eng-review
Validates engineering plan against existing service boundaries, domain model, and ADRs.
Unit-level command — requires active_unit_id
Wraps: gstack /plan-eng-review

## Pre-flight
1. Read session.yaml active_unit_id
   NULL → STOP: run sk.session focus --unit {unit-id} first

## Context loading
- specs/intents/{intent}/units/{unit}/architecture.md (required)
- .specify/memory/service-registry.md
- .specify/memory/domain-model.md
- .specify/memory/architecture-decisions.md

## Invoke
Surface service boundaries + ADR constraints to agent, then invoke gstack /plan-eng-review

## Post-execution
Flag findings that conflict with service-registry.md, domain-model.md, or ADRs.
Suggest sk.adr if a new cross-service architectural decision is introduced.
