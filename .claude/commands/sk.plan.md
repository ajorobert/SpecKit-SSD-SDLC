# sk.plan
Wraps: upstream.plan

## Pre-flight
1. Acquire lock per command-rules.md
2. Verify state.yaml has active_intent, active_unit, active_story set
   - Any NULL → STOP, instruct user to run sk.specify first
3. Load skills in this order:
   a. .claude/skills/domain-model/SKILL.md
   b. .claude/skills/service-registry/SKILL.md
   c. .claude/skills/architecture-decisions/SKILL.md
   d. .claude/skills/standards/SKILL.md (tech-stack.md only)

## Cross-service check
Before executing upstream plan, answer these internally:
- Does this story touch existing service contracts?
  YES → note which contracts, carry into plan
- Does this story introduce new domain entities?
  YES → flag for domain-model.md update post-execution
- Does this story conflict with any active ADR?
  YES → STOP, report conflict to user before proceeding

## Checkpoint gate
Read state.yaml checkpoint_mode:
- validate → verify sk.architecture has run for active unit
  NOT RUN → STOP, instruct user to run sk.architecture first
- confirm | autopilot → proceed

## Execute upstream plan
Read upstream.plan from upstream-adapter.md
Execute upstream plan instructions with full context loaded above
Plan artifact goes to .specify/intents/{intent}/units/{unit}/plan.md
instead of upstream default location

## Confirm checkpoint
If checkpoint_mode = confirm:
  STOP after plan is generated
  Present plan summary to user
  Wait for explicit approval before continuing
  On approval: set state.yaml checkpoint_status: approved

## Post-execution
1. Update domain-model.md if new entities introduced
2. Update service-registry.md if new services or contracts introduced
3. Suggest ADR if cross-service decision was made (do not create without confirmation)
4. Update state.yaml:
   - last_command: sk.plan
   - last_command_at: <timestamp>
   - last_command_status: success
5. Release lock
