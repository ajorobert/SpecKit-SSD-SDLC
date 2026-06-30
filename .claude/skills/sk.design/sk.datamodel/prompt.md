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

- Always: `.claude/skills/data-access-patterns/SKILL.md`
- `cache`, `caching`, `redis`, `hybrid cache`, `l1`, `l2`, `tag invalidation`, `session`, `distributed lock`, `rate limit`, `redlock`, `redis stream` → `.claude/skills/caching-patterns/SKILL.md`
- `search`, `elasticsearch`, `geo`, `index` → `.claude/skills/search-patterns/SKILL.md`
- `file`, `upload`, `attachment`, `image`, `blob`, `storage`, `seaweedfs`, `s3`, `presigned`, `virus`, `scan`, `clamav`, `imagesharp`, `resize`, `thumbnail`, `quarantine`, `exif`, `signed url`, `bucket` → `.claude/skills/file-pipeline-patterns/SKILL.md`

List the packs loaded before continuing.

## Design Output Layout
All design artifacts live under `specs/intents/{intent}/units/{unit}/02-design/`.
This sub-skill writes `02-design/database-design.md` (the unit data model — this is the
relocated, renamed successor to the old `data-model.md`). Read the architecture from
`02-design/architecture.md`.

## Input Artifacts
specs/intents/{intent}/units/{unit}/02-design/architecture.md
.specify/memory/domain-model.md
.specify/memory/standards/data-standards.md
.claude/skills/design-principles/SKILL.md

## Steps
1. [REFINE MODE] if database-design.md exists, [CREATE MODE] if not
2. Check domain-model.md — flag conflicts before writing
3. Design entities following data-standards.md
4. If REFINE: preserve existing entities, mark removed as deprecated
   never delete — append revision note
5. Classify schema changes: additive | breaking
   breaking → flag to user, wait for confirmation
6. Write the data model to `02-design/database-design.md`

## Output Artifacts
specs/intents/{intent}/units/{unit}/02-design/database-design.md
.specify/memory/domain-model.md (updated with new entities)

## Quality Bar
- Data model written to `02-design/database-design.md`
- No entity conflicts with existing domain-model.md
- All required fields per data-standards.md present
- Migration strategy defined for breaking changes
- Revision note appended if REFINE MODE
- Index strategy defined for every query pattern in Access Patterns section
- Transaction boundaries and isolation level declared for each write path
