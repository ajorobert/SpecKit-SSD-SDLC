# sk.tasks
Wraps: upstream.tasks
Story-level command — requires active_story_id

## Pre-flight
1. Read session.yaml active_story_id
   NULL → STOP: run sk.session focus --story {id} first
2. Read story frontmatter
3. Verify plan.md exists:
   specs/intents/{intent}/units/{unit}/stories/{story-id}/plan.md
   MISSING → STOP: run sk.plan first
4. Load skill: .claude/skills/architecture-decisions/SKILL.md
5. Verify checkpoint gate:
   checkpoint_mode = confirm OR validate → checkpoint_status must = approved
   NOT approved → STOP: approval required before tasks

## Execute upstream tasks
Read upstream.tasks from upstream-adapter.md
Execute upstream tasks instructions
Write tasks to:
specs/intents/{intent}/units/{unit}/stories/{story-id}/tasks.md

## Post-execution
Report task count and parallel markers found
