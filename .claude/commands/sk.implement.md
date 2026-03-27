# sk.implement
Wraps: upstream.implement

## Pre-flight
1. Verify state.yaml has active_intent, active_unit, active_story set
   - Any NULL → STOP, instruct user to run sk.specify first
2. Verify these artifacts exist for active unit:
   - plan.md → missing: run sk.plan first
   - tasks.md → missing: run sk.tasks first
   At least one ADR in architecture-decisions.md OR checkpoint_mode = autopilot
   - No ADR AND not autopilot → STOP, instruct user to run sk.architecture first
3. Load skills in this order:
   a. .claude/skills/service-registry/SKILL.md
   b. .claude/skills/architecture-decisions/SKILL.md
   c. .claude/skills/standards/SKILL.md (coding-standards.md only)

## Context redirect
Set FEATURE_DIR to:
.specify/intents/{active_intent}/units/{active_unit}/
This overrides upstream default FEATURE_DIR resolution
Pass this context into upstream implement execution

## Execute upstream implement
Read upstream.implement from upstream-adapter.md
Execute upstream implement instructions in full
Do not duplicate or override any upstream implementation logic
Upstream handles: task execution, TDD ordering, progress tracking,
ignore files, checklist validation, completion validation

## Standards enforcement
During implementation, if code violates coding-standards.md:
- Flag violation immediately
- Do not proceed with that task until resolved

## Post-execution
sk.phr trigger evaluated by post-command hook automatically
