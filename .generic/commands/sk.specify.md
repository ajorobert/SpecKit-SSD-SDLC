<!-- GENERIC LAYER — self-contained command -->
<!-- Before executing: read .generic/hooks/pre-command.md -->
<!-- After executing: read .generic/hooks/post-command.md -->
<!-- Context to load: see .generic/context-maps/command-context-map.md -->

# sk.specify
Wraps: upstream.specify
Role: po

## Pre-flight
1. Read session.yaml — verify role = po
   WARN if different role (do not block, just warn)
2. Load skill: .claude/skills/system-context/SKILL.md
3. Verify system-context.md populated
   EMPTY → STOP, instruct user to run sk.constitution first

## Intent resolution
Check session.yaml active_intent_id:
- NULL → new intent
  1. Ask user for intent title and code (short uppercase e.g. CHK)
  2. Create specs/intents/{NNN}-{intent-name}/ directory
  3. Create intent.md from .your-layer/templates/intent-template.md
  4. Set session.yaml active_intent_id: {INTENT-CODE}
- NOT NULL → confirm or change

## Unit resolution
Ask user: existing unit or new unit?
- NEW:
  1. Ask for unit title and code (e.g. PAY)
  2. Create specs/intents/{intent}/units/{unit-name}/ directory
  3. Create unit-brief.md from .your-layer/templates/unit-brief-template.md
     ID format: {INTENT-CODE}-{UNIT-CODE}
  4. Set session.yaml active_unit_id: {INTENT-CODE}-{UNIT-CODE}
- EXISTING: set session.yaml active_unit_id to selected unit

## Story creation
1. Count existing stories in active unit to get next number
2. Generate story ID: {INTENT-CODE}-{UNIT-CODE}-{NNN} (zero-padded)
3. Execute upstream specify instructions
4. Write output to:
   specs/intents/{intent}/units/{unit}/stories/story-{ID}.md
   using .your-layer/templates/story-template.md as structure
5. Set story frontmatter status: draft

## Checkpoint classification
Load skill: .claude/skills/governance/SKILL.md
Read checkpoint-rules.md
Classify story → set checkpoint_mode in story frontmatter
Report classification with reasoning

## Post-execution
Update session.yaml:
- active_story_id: {story-ID}
- Add story-ID to stories_touched