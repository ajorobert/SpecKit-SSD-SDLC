# sk.tasks
Wraps: upstream.tasks

## Pre-flight
1. Verify state.yaml has active_intent, active_unit, active_story set
   - Any NULL → STOP, instruct user to run sk.specify first
2. Verify plan.md exists for active unit:
   .specify/intents/{active_intent}/units/{active_unit}/plan.md
   - Missing → STOP, instruct user to run sk.plan first
3. Load skill: .claude/skills/architecture-decisions/SKILL.md
4. Verify at least one ADR exists OR checkpoint_mode = autopilot
   - No ADR AND checkpoint_mode != autopilot → warn user, ask to confirm proceed

## Checkpoint gate
Read state.yaml checkpoint_mode:
- confirm → verify checkpoint_status = approved
  NOT approved → STOP, instruct user to approve plan first
- validate → verify checkpoint_status = approved
  NOT approved → STOP
- autopilot → proceed

## Execute upstream tasks
Read upstream.tasks from upstream-adapter.md
Execute upstream tasks instructions
Tasks artifact goes to:
.specify/intents/{active_intent}/units/{active_unit}/tasks.md
instead of upstream default location

## Post-execution
Report task count and parallel execution markers found
