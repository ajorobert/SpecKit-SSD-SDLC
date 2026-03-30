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
knowledge-base.md (relevant tier updated if decision is significant)

## Knowledge Base Update
After writing ADR, evaluate:
- System-level decision → append to specs/knowledge-base.md
  Evolution History section
- Domain-level decision → append to relevant
  specs/domains/{domain}/knowledge-base.md
  What Was Tried and Rejected OR Evolution History section
- Unit-level decision → append to unit knowledge-base.md
  Key Decisions and Their Reasons section

Append only the non-derivable essence:
decision made, why, what was rejected.
Do not duplicate the full ADR content.

## Quality Bar
- Alternatives table populated with at least 2 options
- Consequences has both positive and negative entries
- Affected stories listed in frontmatter
