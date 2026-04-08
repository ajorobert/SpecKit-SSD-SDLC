# sk.ff — Fast Forward
Runs specify → clarify → architecture → plan → tasks in sequence.
Role: lead | Level: story

## Mode Detection
- `sk.ff` → [FEATURE MODE] full pipeline: specify → clarify → architecture → plan → tasks
- `sk.ff --bug` → [BUG MODE] fix pipeline: specify --bug → clarify → plan → tasks
  Architecture step is skipped in bug mode — the unit architecture already exists.
  If the bug fix requires a data model or contract change, stop and run sk.architecture manually.

## Input Artifacts
.specify/memory/system-context.md
session.yaml (active focus)

## Steps

### [FEATURE MODE]
1. Verify system-context.md and tech-stack.md populated
2. Execute sk.specify
3. Read checkpoint_mode from story frontmatter
4. Execute sk.clarify
5. If checkpoint_mode = validate: execute sk.architecture
   PAUSE for approval before continuing
6. Execute sk.plan
   If checkpoint_mode = confirm: PAUSE for approval
7. Execute sk.tasks

### [BUG MODE]
1. Verify system-context.md and tech-stack.md populated
2. Execute sk.specify --bug
3. Read checkpoint_mode from story frontmatter
4. Execute sk.clarify
   Focus clarify on: reproduction conditions, edge cases, regression risk
5. Execute sk.plan
   If checkpoint_mode = confirm: PAUSE for approval
6. Execute sk.tasks

## Output Artifacts
All artifacts from each sub-command

## Quality Bar
- Checkpoint pauses respected
- All artifacts created in correct locations
- Story frontmatter updated throughout
- Bug mode: story_type: bug confirmed in frontmatter before plan proceeds
- Completion report: story ID, artifacts created, next step
