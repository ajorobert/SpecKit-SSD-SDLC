<!-- GENERIC LAYER — self-contained command -->
<!-- Before executing: read .generic/hooks/pre-command.md -->
<!-- After executing: read .generic/hooks/post-command.md -->
<!-- Context to load: see .generic/context-maps/command-context-map.md -->

# sk.ship
Quality-gated release via gstack.
Story-level command — requires active_story_id
Role: lead | Wraps: gstack /ship

## Pre-flight
1. Read session.yaml active_story_id
   NULL → STOP: run sk.session focus --story {id} first

## Hard quality gate
Run sk.verify — must be PASS.
ANY gate FAIL → STOP. Do not proceed.

Hard blocks:
- security-status = BLOCKED → STOP
- test-status ≠ pass → STOP

## Invoke
Surface story title + branch to agent, then invoke gstack /ship

## Post-execution
On success: update story status = done
Report PR URL or deployment reference from gstack output
