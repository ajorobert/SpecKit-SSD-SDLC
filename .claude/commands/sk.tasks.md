# sk.tasks
Generates actionable task breakdown for a story.
Role: lead | Level: story

## Input Artifacts
specs/intents/{intent}/units/{unit}/stories/{story-id}/plan.md (required)
story-{ID}.md frontmatter (checkpoint_status)

## Steps
1. Verify plan.md exists — if missing: STOP, run sk.plan first
2. Verify checkpoint gate:
   confirm or validate mode → checkpoint_status must = approved
   not approved → STOP, instruct user to approve plan first
3. [REFINE MODE] if tasks.md exists, [CREATE MODE] if not
4. Generate task breakdown:
   - Phase 1: Setup (project structure, config, dependencies)
   - Phase 2: Foundational (blocking prerequisites — schema migrations, shared utilities)
   - Phase 3+: User story tasks in priority order
     - Write tests before implementation tasks (TDD order)
     - Mark parallelizable tasks with [P]
     - Each task: checkbox format `- [ ] [T{NNN}] [P?] Description — file/path/target`
   - Final phase: cross-cutting concerns (logging, error handling, documentation)
5. Write tasks to:
   specs/intents/{intent}/units/{unit}/stories/{story-id}/tasks.md

## Output Artifacts
specs/intents/{intent}/units/{unit}/stories/{story-id}/tasks.md

## Quality Bar
- Test tasks before implementation tasks (TDD order)
- Parallel tasks marked [P]
- Each task has explicit file path
- Dependencies between tasks explicit
