# sk.investigate
Spec-aware root-cause debugging — knows what correct behavior looks like.
Role: backend, frontend | Level: story
Wraps: gstack /investigate

## Pre-flight
1. Read session.yaml active_story_id
   NULL → STOP: run sk.session focus --story {id} first

## Context loading
- specs/intents/{intent}/units/{unit}/stories/{story-id}/story-{ID}.md
  → extract acceptance criteria (the expected behavior)
- specs/intents/{intent}/units/{unit}/contracts/api-spec.json
  → expected endpoint contracts
- specs/intents/{intent}/units/{unit}/stories/{story-id}/plan.md
  → intended implementation approach

## Context surface
Before invoking gstack /investigate, surface to agent:

"Investigating story: {story-id} — {story title}
Expected behavior per spec:
{acceptance criteria list}
Contract shape (relevant endpoints):
{relevant api-spec.json endpoints}
Intended implementation approach: {key points from plan.md}"

## Invoke
gstack /investigate

## Post-execution
Classify each finding as one of:
- **Implementation bug**: behavior deviates from correct implementation of the spec → fix in src/
- **Spec/contract mismatch**: spec or contract needs updating → flag to architect;
  may require sk.contracts or sk.clarify before implementation changes

No spec files may be modified based on investigation findings without architect confirmation.

## Quality Bar
- Every finding classified: implementation bug vs. spec deviation
- No spec or contract files modified without architect sign-off
- Root cause documented for each bug finding
