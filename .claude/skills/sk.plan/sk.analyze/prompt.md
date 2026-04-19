# sk.analyze
Cross-artifact consistency check for the active unit.
Role: lead | Level: unit
READ-ONLY — no files written, analysis report only.

Internal sub-skill — invoked by sk.plan orchestrator. Do not invoke directly.

**When to run:** As Phase 2 of the sk.plan orchestrator.
Validates all generated plans against the unit architecture and global models to catch conflicts
and spec drift before implementation.
CRITICAL, HIGH, or MEDIUM findings must be resolved before implementation may proceed.

## Pre-flight
1. Read session.yaml active_unit_id
   NULL → STOP: run sk.session focus --unit {unit-id} first
2. Resolve unit directory:
   UNIT_DIR = specs/intents/{intent}/units/{unit}/

## Context loading
Load these artifacts (report MISSING if required artifact absent):
- UNIT_DIR/architecture.md (required)
- UNIT_DIR/stories/ (list all story-{ID}.md files)
- UNIT_DIR/contracts/api-spec.json (if exists)
- UNIT_DIR/data-model.md (if exists)
- UNIT_DIR/stories/{story-id}/plan.md (for each specified story)
- .specify/memory/service-registry.md
- .specify/memory/domain-model.md
- .specify/memory/architecture-decisions.md

## Consistency checks

### A. Stories coverage
- Every story-{ID}.md in UNIT_DIR/stories/ must appear in architecture.md stories-covered section
- Every story listed in architecture.md stories-covered must have a corresponding story file
- Missing stories: CRITICAL finding

### B. Contract consistency
- Every endpoint in api-spec.json must be referenced or consistent with service-registry.md
- No endpoint in api-spec.json may contradict a registered service boundary
- Contract changes not reflected in service-registry.md: HIGH finding

### C. Data model alignment
- Every entity in UNIT_DIR/data-model.md must be present in .specify/memory/domain-model.md
- Entity attributes must not conflict between unit and global domain model
- Conflicts or missing entities: HIGH finding

### D. Plan alignment
- For each story: plan.md tech choices must not contradict architecture.md
- Dependency on an external service not listed in architecture.md dependencies: HIGH finding

### E. Bounded context integrity
- No entity defined in this unit may be owned by another unit (check service-registry.md)
- Cross-unit access must go through a defined contract endpoint, not direct coupling
- Boundary violations: CRITICAL finding

### F. ADR constraint compliance
- Check each ADR in architecture-decisions.md that applies to this unit
- Flag any story or plan element that violates an ADR decision
- ADR violations: CRITICAL finding

## Report format
Output a Markdown report with:

| ID | Check | Severity | Location | Finding | Recommendation |
|----|-------|----------|----------|---------|----------------|

Severity scale: CRITICAL | HIGH | MEDIUM | LOW

Followed by:
- **Summary**: total findings by severity
- **Coverage map**: story-{ID} → in architecture.md (yes/no)
- **Next actions**: if any MEDIUM, HIGH, or CRITICAL findings exist, list all findings. The user must resolve them and re-run sk.plan --analyze-only before proceeding to implementation. LOW findings are reported but do not block.

If no findings: report "All consistency checks passed" with coverage metrics.

## Quality Bar
- All stories covered by architecture
- No bounded context violations
- No ADR constraint violations
- No entity conflicts with global domain model
