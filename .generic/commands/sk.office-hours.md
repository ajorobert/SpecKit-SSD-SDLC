<!-- GENERIC LAYER — self-contained command -->
<!-- Before executing: read .generic/hooks/pre-command.md -->
<!-- After executing: read .generic/hooks/post-command.md -->
<!-- Context to load: see .generic/context-maps/command-context-map.md -->

# sk.office-hours [OPTIONAL]
Validates product ideas or feature approaches before committing to spec work.
Wraps: gstack /office-hours

This command is OPTIONAL. Use when initiating a new intent or evaluating a complex unit.

## Pre-flight
1. Read session.yaml
2. Detect scope:
   active_unit_id SET → unit-level: feature approach validation
   active_unit_id NULL → intent-level: product/initiative validation

## Context loading

### Intent-level
- .specify/memory/system-context.md
- specs/intents/ — existing intents list
- .specify/memory/architecture-decisions.md
- .specify/memory/domain-model.md

### Unit-level (add to above)
- specs/intents/{intent}/units/{unit}/unit-brief.md
- specs/intents/{intent}/units/{unit}/architecture.md (if exists)

## Invoke
Surface scope + context to agent, then invoke gstack /office-hours

## Post-execution
Major scope concerns → suggest updating intent.md or unit-brief.md before proceeding
