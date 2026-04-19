# sk.datamodel
Defines data model for a unit.
Role: architect | Level: unit
ONE document per unit.

Internal sub-skill — invoked by sk.design. Do not invoke directly.

## Step 0: Capability Pack Selection
Load data-layer packs before designing the model.

1. Read session.yaml → get `active_unit`
2. Read unit stories → check `tags` for data-domain keywords
3. Read applicable packs. **Load ≤4 packs total.**

- Always: `.claude/skills/postgresql-patterns/SKILL.md`
- `cache`, `redis`, `session`, `rate-limit`, `lock` → `.claude/skills/redis-patterns/SKILL.md`
- `search`, `elasticsearch`, `geo`, `index` → `.claude/skills/elasticsearch-patterns/SKILL.md`
- `file`, `upload`, `storage` → `.claude/skills/file-storage-patterns/SKILL.md`

List the packs loaded before continuing.

## Input Artifacts
specs/intents/{intent}/units/{unit}/architecture.md
.specify/memory/domain-model.md
.specify/memory/standards/data-standards.md
.claude/skills/design-principles/SKILL.md

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
- Index strategy defined for every query pattern in Access Patterns section
- Transaction boundaries and isolation level declared for each write path
