# sk.analyze
Wraps: upstream.analyze
Unit-level command — requires active_unit_id

## Pre-flight
1. Read session.yaml active_unit_id
   NULL → STOP: run sk.session focus --unit {id} first
2. Load skill: .claude/skills/architecture-decisions/SKILL.md

## Execute upstream analyze
Read upstream.analyze from upstream-adapter.md
Execute upstream analyze instructions in full

## Post-execution
If analysis surfaces cross-service inconsistencies:
- Flag to user
- Suggest sk.architecture review
