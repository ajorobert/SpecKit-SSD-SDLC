# sk.analyze
Cross-artifact consistency check for active unit.
Role: lead, architect | Level: unit

## Input Artifacts
All artifacts in active unit directory
.specify/memory/architecture-decisions.md

## Steps
1. Execute upstream.analyze from upstream-adapter.md in full
2. Flag cross-service inconsistencies to user
   suggest sk.architecture review if found

## Output Artifacts
None — analysis only, no files written

## Quality Bar
- All stories in unit covered by architecture
- No contract conflicts between services
