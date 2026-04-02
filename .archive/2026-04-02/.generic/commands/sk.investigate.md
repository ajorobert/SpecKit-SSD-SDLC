<!-- GENERIC LAYER — self-contained command -->
<!-- Before executing: read .generic/hooks/pre-command.md -->
<!-- After executing: read .generic/hooks/post-command.md -->
<!-- Context to load: see .generic/context-maps/command-context-map.md -->

# sk.investigate
Spec-aware root-cause debugging.
Story-level command — requires active_story_id
Wraps: gstack /investigate

## Pre-flight
1. Read session.yaml active_story_id
   NULL → STOP: run sk.session focus --story {id} first

## Context loading
- story-{ID}.md → acceptance criteria (expected behavior)
- contracts/api-spec.json → expected endpoint contracts
- plan.md → intended implementation approach

## Invoke
Surface expected behavior + contract shape to agent, then invoke gstack /investigate

## Post-execution
Classify each finding:
- Implementation bug → fix in src/
- Spec/contract mismatch → flag to architect; no spec changes without confirmation
