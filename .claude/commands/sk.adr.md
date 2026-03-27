sk.adr
Load skill: .claude/skills/architecture-decisions/SKILL.md

Pre-flight
- Acquire lock per command-rules.md
- Read .specify/memory/architecture-decisions.md
- Determine next ADR number from active decisions table

Steps

1. Collect from user:
   - Title
   - Context (what situation forced this decision)
   - Decision (what was chosen)
   - Alternatives considered
   - Consequences (positive and negative)

2. Run .your-layer/scripts/create-adr.sh <next-number> "<title>"
3. Write the ADR using .your-layer/templates/adr-template.md
   into the file created by the script
4. Update .specify/memory/architecture-decisions.md Active Decisions table
5. Update state.yaml: last_command, last_command_at, last_command_status
6. Release lock
