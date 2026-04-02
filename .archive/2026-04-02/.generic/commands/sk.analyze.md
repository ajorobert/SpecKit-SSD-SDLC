<!-- GENERIC LAYER — self-contained command -->
<!-- Before executing: read .generic/hooks/pre-command.md -->
<!-- After executing: read .generic/hooks/post-command.md -->
<!-- Context to load: see .generic/context-maps/command-context-map.md -->

# sk.analyze
Cross-artifact consistency check for the active unit.
Unit-level command — requires active_unit_id
READ-ONLY — no files written, analysis report only.

## Pre-flight
1. Read session.yaml active_unit_id
   NULL → STOP: run sk.session focus --unit {unit-id} first
2. Load skill: .claude/skills/architecture-decisions/SKILL.md

## Context loading
Load these artifacts (report MISSING if required artifact absent):
- UNIT_DIR/architecture.md (required)
- UNIT_DIR/stories/ (list all story-{ID}.md files)
- UNIT_DIR/contracts/api-spec.json (if exists)
- UNIT_DIR/data-model.md (if exists)
- UNIT_DIR/plan.md (if exists, for each story)
- .specify/memory/service-registry.md
- .specify/memory/domain-model.md
- .specify/memory/architecture-decisions.md

## Consistency checks

### A. Stories coverage
Every story-{ID}.md in stories/ must appear in architecture.md stories-covered.
Every story listed in architecture.md must have a corresponding story file.

### B. Contract consistency
Every endpoint in api-spec.json must be consistent with service-registry.md.
No endpoint may contradict a registered service boundary.

### C. Data model alignment
Every entity in data-model.md must be present in .specify/memory/domain-model.md.
Entity attributes must not conflict between unit and global domain model.

### D. Plan alignment
Each story plan.md tech choices must not contradict architecture.md.

### E. Bounded context integrity
No entity in this unit may be owned by another unit (check service-registry.md).
Cross-unit access must go through a defined contract endpoint, not direct coupling.

### F. ADR constraint compliance
Each ADR in architecture-decisions.md that applies to this unit must be respected.

## Report format
Output a Markdown report with findings table:

| ID | Check | Severity | Location | Finding | Recommendation |
|----|-------|----------|----------|---------|----------------|

Severity: CRITICAL | HIGH | MEDIUM | LOW

Followed by:
- **Summary**: total findings by severity
- **Coverage map**: story-{ID} → in architecture.md (yes/no)
- **Next actions**: CRITICAL findings must be resolved before sk.implement proceeds

## Post-execution
If CRITICAL findings: flag to user, suggest sk.architecture review
