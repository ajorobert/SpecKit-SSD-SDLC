Pattern Reference Archive
These files contain spec-kit's AI prompting patterns. They are SOURCE REFERENCES only —
never executed at runtime. All logic has been inlined into sk.* commands.

## Migration Note
Runtime delegation to upstream commands was removed because spec-kit's templates
require shell scripts (create-new-feature.sh, setup-plan.sh, check-prerequisites.sh)
that write artifacts to a FEATURE_DIR structure incompatible with our
Intent → Unit → Story hierarchy. The AI prompting patterns in these templates
were extracted, adapted to our file paths, and inlined directly into sk.* commands.

## Pattern Sources
upstream.specify      → .speckit/upstream/templates/commands/specify.md
upstream.plan         → .speckit/upstream/templates/commands/plan.md
upstream.tasks        → .speckit/upstream/templates/commands/tasks.md
upstream.implement    → .speckit/upstream/templates/commands/implement.md
upstream.clarify      → .speckit/upstream/templates/commands/clarify.md
upstream.analyze      → .speckit/upstream/templates/commands/analyze.md
upstream.constitution → .speckit/upstream/templates/commands/constitution.md
upstream.checklist    → .speckit/upstream/templates/commands/checklist.md

## Explicitly Excluded Upstream Commands
upstream.taskstoissues → .speckit/upstream/templates/commands/taskstoissues.md
Reason: GitHub-specific workflow, outside SpecKit-SSD-SDLC scope.
