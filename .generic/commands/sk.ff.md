<!-- GENERIC LAYER — self-contained command -->
<!-- Before executing: read .generic/hooks/pre-command.md -->
<!-- After executing: read .generic/hooks/post-command.md -->
<!-- Context to load: see .generic/context-maps/command-context-map.md -->

# sk.ff — Fast Forward
Runs full spec-to-tasks pipeline in one shot for standard features.
Sequence: sk.specify → sk.clarify → sk.architecture → sk.plan → sk.tasks

## Pre-flight
1. Read session.yaml — verify role and session active
2. Load skill: .claude/skills/system-context/SKILL.md
3. Verify system-context.md and tech-stack.md populated

## Execution sequence

### Phase 1: Specify
Execute sk.specify in full
Read checkpoint_mode from story frontmatter after completion

### Phase 2: Clarify
Execute sk.clarify in full
If scope changed: re-classify checkpoint_mode, update story frontmatter

### Phase 3: Architecture (conditional)
checkpoint_mode = validate only:
  Execute sk.architecture in full
  PAUSE: present architecture summary
  Wait for explicit approval
  On approval: set story frontmatter checkpoint_status: approved
autopilot | confirm: SKIP sk.architecture

### Phase 4: Plan
Execute sk.plan in full
checkpoint_mode = confirm:
  PAUSE: present plan summary
  Wait for explicit approval
  On approval: set story frontmatter checkpoint_status: approved
autopilot | validate (already approved): proceed

### Phase 5: Tasks
Execute sk.tasks in full

## Completion report
- Story ID, checkpoint mode applied
- Artifacts created with paths
- ADR suggestions raised
- Next step: sk.implement {story-id}