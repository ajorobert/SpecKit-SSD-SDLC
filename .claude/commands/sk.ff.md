# sk.ff — Fast Forward
Runs the full spec-to-tasks pipeline in one shot.
Sequence: sk.specify → sk.clarify → sk.architecture → sk.plan → sk.tasks
Pauses at every Confirm and Validate checkpoint automatically.

## Pre-flight
1. Verify system-context.md and standards/tech-stack.md are populated
   - Either empty → STOP, instruct user to run sk.constitution first
2. Load skill: .claude/skills/system-context/SKILL.md

## Execution sequence

### Phase 1: Specify
Execute sk.specify in full
After completion: read state.yaml checkpoint_mode

### Phase 2: Clarify
Execute sk.clarify in full
If clarification changes scope: re-run checkpoint classification
Update state.yaml checkpoint_mode if classification changes

### Phase 3: Architecture
Execute only if checkpoint_mode = validate
- autopilot → SKIP sk.architecture, proceed to Phase 4
- confirm → SKIP sk.architecture, proceed to Phase 4
- validate → execute sk.architecture in full
  PAUSE: present architecture summary to user
  Wait for explicit approval before Phase 4
  On approval: set state.yaml checkpoint_status: approved

### Phase 4: Plan
Execute sk.plan in full
If checkpoint_mode = confirm:
  PAUSE: present plan summary to user
  Wait for explicit approval before Phase 5
  On approval: set state.yaml checkpoint_status: approved
If checkpoint_mode = autopilot | validate (already approved):
  Proceed automatically

### Phase 5: Tasks
Execute sk.tasks in full

## Completion
Report summary:
- Intent, unit, story
- Checkpoint mode applied
- Artifacts created
- Any ADR suggestions raised
- Ready for: sk.implement
