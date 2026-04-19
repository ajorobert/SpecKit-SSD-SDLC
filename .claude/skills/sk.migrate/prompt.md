# sk.migrate
Database migration lifecycle — expand/contract pattern.
Role: backend | Level: unit

## Mode detection
- `sk.migrate --expand`   → [EXPAND] add-only changes (new columns, tables, indexes)
- `sk.migrate --contract` → [CONTRACT] remove old columns/tables after all consumers migrated
- `sk.migrate --rollback` → [ROLLBACK PLAN] generate rollback script for a named migration
- `sk.migrate` (no flag)  → prompt user to select mode
Declare mode at start of execution.

## Pre-flight
1. Read session.yaml active_unit
   NULL → STOP: run sk.session focus --unit {unit} first
2. Verify data-model.md exists: specs/intents/{intent}/units/{unit}/data-model.md
   MISSING → STOP: run sk.datamodel first
3. List existing migration files in src/{service}/Migrations/ or equivalent path
4. In [CONTRACT] mode: verify corresponding expand migration is present and deployed
   UNVERIFIED → warn user; require explicit confirmation before generating contract migration

## Context loading
1. specs/intents/{intent}/units/{unit}/data-model.md — canonical entity definitions
2. specs/intents/{intent}/units/{unit}/architecture.md (if exists)
3. .specify/memory/standards/data-standards.md
4. .claude/skills/postgresql-patterns/SKILL.md

## [EXPAND] steps
1. Identify new entities, columns, indexes, constraints from data-model.md diff
2. Generate migration file:
   - Filename: {timestamp}_{story-id}_{descriptive-name}.sql or EF Core class per stack
   - Content: add-only — no DROP, no ALTER with data loss risk
   - Include: forward migration + idempotency guard (IF NOT EXISTS where applicable)
3. Annotate each change with its data-model.md source entity
4. Generate rollback script: reverse of each add (DROP the added objects)
5. Write rollback-plan.md (see Output Artifacts)

## [CONTRACT] steps
1. Confirm all consumers have been migrated off deprecated columns/tables
   Ask: "Confirm all services consuming {deprecated columns} have been updated? (y/n)"
   On n → STOP: contract migration is unsafe until all consumers are migrated
2. Generate migration file: DROP deprecated objects
3. Include tombstone comment: `-- Expanded in migration {expand-migration-filename}`
4. Rollback note: "Contract migrations cannot be auto-rolled back — restore from expand migration + data backup"

## [ROLLBACK PLAN] steps
1. Ask: which migration filename to target?
2. Read the target migration
3. Generate reverse operations in dependency order (FKs before tables, indexes before columns)
4. Annotate data-loss risk for each step (SAFE / DATA LOSS: {what is lost})
5. Write rollback-plan.md

## Migration test generation
After any migration file, generate a migration test:
- Test: migration applies cleanly from prior state
- Test: rollback script restores prior state (expand only)
- Test: idempotency — applying twice has no effect
Write tests to src/{service}/Tests/Migrations/{migration-name}Tests.cs (or equivalent)

## Output Artifacts
src/{service}/Migrations/{timestamp}_{story-id}_{name}.{ext}
src/{service}/Tests/Migrations/{name}Tests.{ext}
specs/intents/{intent}/units/{unit}/stories/{story-id}/rollback-plan.md

## Quality Bar
- Expand migrations: zero DROP or destructive ALTER statements
- Contract migrations: explicit consumer-migrated confirmation recorded
- Every migration has a corresponding rollback script or documented data-loss caveat
- Migration tests cover apply, rollback (expand), and idempotency
- Rollback plan documents DATA LOSS risk per step
