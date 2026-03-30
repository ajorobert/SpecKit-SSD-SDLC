<!-- GENERIC LAYER — self-contained command -->
<!-- Before executing: read .generic/hooks/pre-command.md -->
<!-- After executing: read .generic/hooks/post-command.md -->
<!-- Context to load: see .generic/context-maps/command-context-map.md -->

# sk.adr
Load skill: .claude/skills/architecture-decisions/SKILL.md

## Pre-flight
1. Read session.yaml — get active_intent_id, active_unit_id
2. Read .specify/memory/architecture-decisions.md
3. Determine next ADR number

## Steps
1. Collect from user:
   - Title
   - Context
   - Decision
   - Alternatives considered
   - Consequences

2. Run .your-layer/scripts/create-adr.sh <number> "<title>"

3. Write ADR using .your-layer/templates/adr-template.md
   Include in frontmatter:
   - intent: active_intent_id
   - unit: active_unit_id (if unit-scoped)
   - stories: list any story IDs this decision affects

4. Update .specify/memory/architecture-decisions.md index