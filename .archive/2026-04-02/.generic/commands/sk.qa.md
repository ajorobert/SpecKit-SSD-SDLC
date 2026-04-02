<!-- GENERIC LAYER — self-contained command -->
<!-- Before executing: read .generic/hooks/pre-command.md -->
<!-- After executing: read .generic/hooks/post-command.md -->
<!-- Context to load: see .generic/context-maps/command-context-map.md -->

# sk.qa
Browser acceptance testing against story acceptance criteria.
Story-level command — requires active_story_id
Role: frontend-qa only | Wraps: gstack /qa

## Pre-flight
1. Read session.yaml active_story_id
   NULL → STOP: run sk.session focus --story {id} first
2. Verify role = frontend-qa
   Other role → STOP: "sk.qa requires frontend-qa role"

## Context loading
- story-{ID}.md → acceptance criteria (each = a test scenario)
- contracts/test-plan.md → consumer section

## Invoke
Surface acceptance criteria + consumer scenarios to agent, then invoke gstack /qa

## Post-execution
Map each finding to its acceptance criterion.
Update story-{ID}.md:
- test-status = pass if all AC scenarios pass
- test-status = fail if any AC scenario fails (document which)
