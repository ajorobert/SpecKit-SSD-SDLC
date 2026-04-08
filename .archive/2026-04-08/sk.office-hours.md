# sk.office-hours [OPTIONAL]
Validates product ideas or feature approaches before committing to spec work.
Role: po, architect | Level: intent (product validation) or unit (feature validation)
Wraps: gstack /office-hours

This command is OPTIONAL. Use when initiating a new intent or evaluating a complex unit
where early feedback reduces rework risk. Not required in every flow.

## Pre-flight
1. Read session.yaml
2. Detect scope level:
   - active_unit_id IS SET → unit-level: feature approach validation
   - active_unit_id IS NULL → intent-level: product/initiative validation
3. Report detected scope level to user before proceeding

## Context loading

### Intent-level scope
- .specify/memory/system-context.md — what we're building and why
- specs/intents/ — list existing intents (avoid duplicating scope)
- .specify/memory/architecture-decisions.md — constraints that apply
- .specify/memory/domain-model.md — existing domain entities

### Unit-level scope (all of above, plus)
- specs/intents/{intent}/units/{unit}/unit-brief.md — active unit definition
- specs/intents/{intent}/units/{unit}/architecture.md (if exists)

## Context surface
Before invoking gstack /office-hours, surface to agent:

**Intent-level:**
"Scope: product/initiative validation.
System purpose: {system-context summary}
Existing intents: {list intent names}
ADR constraints: {relevant ADRs}
Question: {user's input or idea}"

**Unit-level:**
"Scope: feature approach validation.
Unit: {unit name} — {unit purpose from unit-brief.md}
System purpose: {system-context summary}
ADR constraints: {relevant ADRs}
Question: {user's input or idea}"

## Invoke
gstack /office-hours

## Post-execution
If major scope concerns raised:
- Intent-level: suggest updating intent.md open questions before sk.specify
- Unit-level: suggest updating unit-brief.md before sk.architecture

## Quality Bar
- Scope level correctly detected and surfaced
- No existing intent duplicated
- Findings documented in session notes or relevant intent/unit file
