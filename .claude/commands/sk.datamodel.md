# sk.datamodel
Unit-level command. ONE data model per unit.

## Pre-flight
1. Read session.yaml active_unit_id
   NULL → STOP: run sk.session focus --unit {id} first
2. Load skills:
   a. .claude/skills/domain-model/SKILL.md
   b. .claude/skills/standards/SKILL.md (data-standards.md only)
3. Read unit architecture.md if exists — data model must align with it
4. Check if data-model.md exists for active unit:
   EXISTS → [REFINE MODE]
   MISSING → [CREATE MODE]

## Steps

### A. Entity discovery
From unit architecture.md and stories in this unit:
- List all domain entities required
- Check domain-model.md — flag any conflicts with existing entities
- Identify shared kernel entities that must not be duplicated

### B. Entity design
For each new entity define:
- Fields with types and constraints
- Required fields per data-standards.md
- Relationships to other entities
- Indexes required
- Soft delete approach per data-standards.md

### C. Migration strategy
- What schema changes are required?
- Are changes backward compatible?
- Is a data migration required?
- Risk level: additive | breaking

### D. Write data model document
Target: specs/intents/{intent}/units/{unit}/data-model.md

If [REFINE MODE]:
  1. Read existing data-model.md fully
  2. Identify new or modified entities from current session context
  3. Preserve all existing entities that remain valid
  4. Add new entities, update modified ones
  5. Flag any removed entities as deprecated, do not delete:
     Status: deprecated | Reason: {reason} | Date: {date}
  6. Append revision note:
     ---
     Revised: {date}
     Session: {session_id}
     Changes: {entities added, modified, deprecated}
     ---

If [CREATE MODE]:
  Write fresh document using this structure:

  ---
  unit: {unit-id}
  intent: {intent-id}
  updated: {date}
  ---

  # Data Model: {unit-name}

  ## Entities
  ### {EntityName}
  | Field | Type | Required | Description |
  |-------|------|----------|-------------|

  ## Relationships

  ## Indexes

  ## Migration Notes

## Post-execution
Post-command hook updates domain-model.md automatically
Flag to user if any breaking schema changes detected
