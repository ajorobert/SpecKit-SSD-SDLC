# sk.adr
Creates an Architecture Decision Record.
Role: architect | Level: unit or intent

## Input Artifacts
.specify/memory/architecture-decisions.md
session.yaml (active_intent_id, active_unit_id)

## Steps
1. Determine next ADR number from architecture-decisions.md
2. Collect: title, context, decision, alternatives, consequences
3. Run .your-layer/scripts/create-adr.sh {number} "{title}"
4. Write ADR using adr-template.md
   Include intent, unit, affected story IDs in frontmatter
5. Update architecture-decisions.md index

## Output Artifacts
history/adr/ADR-{NNN}-{title}.md
.specify/memory/architecture-decisions.md (index updated)

## Quality Bar
- Alternatives table populated with at least 2 options
- Consequences has both positive and negative entries
- Affected stories listed in frontmatter
