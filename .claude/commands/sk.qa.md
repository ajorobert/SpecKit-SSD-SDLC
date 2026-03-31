# sk.qa
Browser acceptance testing against story acceptance criteria.
Role: frontend-qa | Level: story
Wraps: gstack /qa
Frontend only — backend uses sk.test for contract and integration tests.

## Pre-flight
1. Read session.yaml active_story_id
   NULL → STOP: run sk.session focus --story {id} first
2. Verify role = frontend-qa in session.yaml
   Other role → STOP: "sk.qa requires frontend-qa role. Run sk.session switch --role frontend-qa"

## Context loading
- specs/intents/{intent}/units/{unit}/stories/{story-id}/story-{ID}.md
  → extract acceptance criteria — each criterion becomes a test scenario
- specs/intents/{intent}/units/{unit}/contracts/test-plan.md
  → consumer section: E2E scenarios and component test scope

## Context surface
Before invoking gstack /qa, surface to agent:

"Acceptance testing story: {story-id} — {story title}
Test against these acceptance criteria (each = a required test scenario):
{numbered list of acceptance criteria}
Consumer contract scenarios:
{relevant entries from test-plan.md consumer section}"

## Invoke
gstack /qa

## Post-execution
Map each gstack /qa finding to the acceptance criterion it relates to.

Update story-{ID}.md:
- test-status = pass — if gstack /qa PASS on ALL acceptance criteria scenarios
- test-status = fail — if any AC scenario fails (document which criteria failed)

## Quality Bar
- Every acceptance criterion has a mapped test result
- gstack /qa must report PASS on all AC-mapped scenarios before test-status = pass
- No acceptance criterion left unmapped
