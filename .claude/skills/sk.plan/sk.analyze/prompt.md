# sk.analyze
Cross-artifact consistency check for the active story (across its projects).
Role: lead | Level: story
READ-ONLY — no files written, analysis report only.

Internal sub-skill — invoked by sk.plan orchestrator. Do not invoke directly.

**When to run:** As Phase 2 of the sk.plan orchestrator.
Validates all per-project plans against the story design and global models to catch conflicts
and spec drift before implementation.
CRITICAL, HIGH, or MEDIUM findings must be resolved before implementation may proceed.

## Pre-flight (per story-lifecycle.md §3)
1. Resolve `UNIT_DIR` from session.yaml `unit_dir`/`active_story_id`.
   NULL → STOP: run sk.session/sk.story first.
   (Legacy fallback: UNIT_DIR = specs/intents/{intent}/units/{unit}/.)

## Context loading
Load these artifacts (report MISSING if required artifact absent):
- UNIT_DIR/02-design/architecture.md (required)
- UNIT_DIR/stories/ (story.md, acceptance-criteria.md)
- UNIT_DIR/02-design/api-spec.json (if exists)
- UNIT_DIR/02-design/database-design.md (if exists)
- UNIT_DIR/02-design/projects/*.md (per-project design impact)
- UNIT_DIR/03-plan/{ProjectName}/plan.md (for each planned project)
- .specify/memory/projects/index.md
- .specify/memory/service-registry.md
- .specify/memory/domain-model.md
- .specify/memory/architecture-decisions.md

## Consistency checks

### A. Story/acceptance coverage
- Every acceptance criterion in stories/ (acceptance criteria in the story files) must be addressed by at least one
  project plan (`03-plan/{ProjectName}/plan.md`) or design artifact
- Every project with a `02-design/projects/{ProjectName}.md` impact file must have a plan
- Uncovered criteria or missing project plans: CRITICAL finding

### B. Contract consistency
- Every endpoint in api-spec.json must be referenced or consistent with service-registry.md
- No endpoint in api-spec.json may contradict a registered service boundary
- Contract changes not reflected in service-registry.md: HIGH finding

### C. Data model alignment
- Every entity in 02-design/database-design.md must be present in .specify/memory/domain-model.md
- Entity attributes must not conflict between the story design and global domain model
- Conflicts or missing entities: HIGH finding

### D. Plan alignment
- For each project: plan.md tech choices must not contradict architecture.md
- Cross-project dependencies must be consistent (no project depends on a contract another project
  is not exposing); circular project dependencies: HIGH finding
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
