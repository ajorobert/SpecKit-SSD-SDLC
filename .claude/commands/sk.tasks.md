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
4. Execute upstream.tasks from upstream-adapter.md
5. Write tasks to story directory

## Output Artifacts
specs/intents/{intent}/units/{unit}/stories/{story-id}/tasks.md

## Quality Bar
- Test tasks before implementation tasks (TDD order)
- Parallel tasks marked [P]
- Each task has explicit file path
- Dependencies between tasks explicit
