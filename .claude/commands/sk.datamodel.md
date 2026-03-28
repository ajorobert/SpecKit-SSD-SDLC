# sk.datamodel
Defines data model for a unit.
Role: architect | Level: unit
ONE document per unit.

## Input Artifacts
specs/intents/{intent}/units/{unit}/architecture.md
.specify/memory/domain-model.md
.specify/memory/standards/data-standards.md

## Steps
1. [REFINE MODE] if data-model.md exists, [CREATE MODE] if not
2. Check domain-model.md — flag conflicts before writing
3. Design entities following data-standards.md
4. If REFINE: preserve existing entities, mark removed as deprecated
   never delete — append revision note
5. Classify schema changes: additive | breaking
   breaking → flag to user, wait for confirmation

## Output Artifacts
specs/intents/{intent}/units/{unit}/data-model.md
.specify/memory/domain-model.md (updated with new entities)

## Quality Bar
- No entity conflicts with existing domain-model.md
- All required fields per data-standards.md present
- Migration strategy defined for breaking changes
- Revision note appended if REFINE MODE
