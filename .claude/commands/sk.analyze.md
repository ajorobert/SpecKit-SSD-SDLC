# sk.analyze
Wraps: upstream.analyze
Thin wrapper — upstream handles all analysis logic.

## Pre-flight
1. Verify state.yaml has active_unit set
   - NULL → STOP, instruct user to run sk.specify first
2. Load skill: .claude/skills/architecture-decisions/SKILL.md

## Execute upstream analyze
Read upstream.analyze from upstream-adapter.md
Execute upstream analyze instructions in full

## Post-execution
If analysis surfaces inconsistencies across service boundaries:
- Flag to user
- Suggest sk.architecture review before proceeding to sk.tasks
