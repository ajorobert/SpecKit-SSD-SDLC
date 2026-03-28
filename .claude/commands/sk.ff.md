# sk.ff — Fast Forward
Runs specify → clarify → architecture → plan → tasks in sequence.
Role: lead | Level: story

## Input Artifacts
.specify/memory/system-context.md
session.yaml (active focus)

## Steps
1. Verify system-context.md and tech-stack.md populated
2. Execute sk.specify
3. Read checkpoint_mode from story frontmatter
4. Execute sk.clarify
5. If checkpoint_mode = validate: execute sk.architecture
   PAUSE for approval before continuing
6. Execute sk.plan
   If checkpoint_mode = confirm: PAUSE for approval
7. Execute sk.tasks

## Output Artifacts
All artifacts from each sub-command

## Quality Bar
- Checkpoint pauses respected
- All artifacts created in correct locations
- Story frontmatter updated throughout
- Completion report: story ID, artifacts created, next step
