<!-- GENERIC LAYER — self-contained command -->
<!-- Before executing: read .generic/hooks/pre-command.md -->
<!-- After executing: read .generic/hooks/post-command.md -->
<!-- Context to load: see .generic/context-maps/command-context-map.md -->

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

## Generate tasks
Generate task breakdown and write to:
specs/intents/{intent}/units/{unit}/stories/{story-id}/tasks.md

Structure:
- Phase 1: Setup (project structure, config, dependencies)
- Phase 2: Foundational (blocking prerequisites — schema migrations, shared utilities)
- Phase 3+: User story tasks in priority order
  - Write test tasks before implementation tasks (TDD order)
  - Mark parallelizable tasks with [P]
  - Each task: `- [ ] [T{NNN}] [P?] Description — file/path/target`
- Final phase: cross-cutting concerns (logging, error handling)

## Post-execution
Report task count and parallel markers found