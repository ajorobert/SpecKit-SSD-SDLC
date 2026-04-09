# Command Rules

## Session
Every sk.* command reads .claude/session.yaml for active focus (intent/unit/story IDs).
Session focus required for story/unit commands — run sk.session focus if null.
sk.session start --role is optional; role is no longer a prerequisite for most commands.

## Role Behavior

### Group A — Role-enforced (session role required)
sk.implement, sk.test, sk.review, sk.investigate
These branch on backend vs. frontend. Session role must be set before running.

### Group B — Self-asserting (no session role needed)
sk.specify (po), sk.architecture, sk.datamodel, sk.contracts, sk.adr, sk.impact,
sk.knowledge-base (architect), sk.plan, sk.tasks, sk.ff, sk.ship (lead),
sk.security-audit (security), sk.uat (frontend-qa)
Command declares its own role — session role not consulted.

### Group C — Self-asserting with defined default
sk.clarify → architect
sk.analyze → lead
sk.verify → architect
No session role needed. Command operates under its declared default role.

### Group D — Role-agnostic
sk.phr, sk.session — no role, work for anyone.

## Idempotency
Artifact exists → [REFINE MODE] update, never overwrite.
Artifact missing → [CREATE MODE] create from template.
Declare mode at start of every execution.

## Upstream Reference
upstream/ is a pattern reference archive — not executed at runtime.
spec-kit AI prompting patterns have been inlined into sk.* commands.
Do not invoke upstream shell scripts. Do not reference upstream-adapter.md for execution.
See upstream-adapter.md for the migration rationale and pattern source map.
