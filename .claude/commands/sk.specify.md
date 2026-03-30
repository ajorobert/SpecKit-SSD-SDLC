# sk.specify
Captures intent, decomposes to units and stories.
Role: po | Level: intent → unit → story

## Input Artifacts
.specify/memory/system-context.md
session.yaml (active_intent_id, active_unit_id)

## Steps
1. Resolve intent: read active_intent_id from session.yaml
   NULL → ask user for intent title and code (e.g. CHK)
   Create specs/intents/{NNN}-{name}/intent.md if new
2. Resolve unit: read active_unit_id from session.yaml
   NULL → ask user for unit title and code (e.g. PAY)
   Create specs/intents/{intent}/units/{unit}/unit-brief.md if new
3. Execute upstream.specify from upstream-adapter.md
4. Write story to:
   specs/intents/{intent}/units/{unit}/stories/story-{ID}.md
   using story-template.md, ID format: {INTENT}-{UNIT}-{NNN}
5. Classify checkpoint: read governance skill → set checkpoint_mode
   in story frontmatter

## Output Artifacts
specs/intents/{intent}/intent.md (if new)
specs/intents/{intent}/units/{unit}/unit-brief.md (if new)
specs/intents/{intent}/units/{unit}/stories/story-{ID}.md

## Quality Bar
- Story has clear user story format
- Minimum 3 acceptance criteria
- checkpoint_mode set in frontmatter
- Out of scope items listed
