<!-- GENERIC LAYER — self-contained command -->
<!-- Before executing: read .generic/hooks/pre-command.md -->
<!-- After executing: read .generic/hooks/post-command.md -->
<!-- Context to load: see .generic/context-maps/command-context-map.md -->

# sk.implement
Wraps: upstream.implement
Story-level command — requires active_story_id

## Pre-flight
1. Read session.yaml active_story_id
   NULL → STOP: run sk.session focus --story {id} first
2. Read story frontmatter — verify status = ready
3. Verify artifacts exist:
   - plan.md → missing: run sk.plan first
   - tasks.md → missing: run sk.tasks first
4. Load skills:
   a. .claude/skills/service-registry/SKILL.md
   b. .claude/skills/architecture-decisions/SKILL.md
   c. .claude/skills/standards/SKILL.md (coding-standards.md only)
5. Read unit architecture.md for implementation context

## Context redirect
Set FEATURE_DIR to story directory:
specs/intents/{intent}/units/{unit}/stories/{story-id}/

## Execute upstream implement
Read upstream.implement from upstream-adapter.md
Execute upstream implement instructions in full
Do not duplicate upstream logic

## Standards enforcement
Flag any coding-standards.md violation immediately
Do not proceed with that task until resolved

## Post-execution
Story status update handled by post-command hook
PHR trigger evaluated by post-command hook