# Skill Rules

## Session
Every sk.* skill reads .claude/session.yaml for active focus (intent/unit/story IDs).
Session focus required for story/unit skills — run sk.session focus if null.
sk.session start --role is optional; role is no longer a prerequisite for most skills.

## Role Behavior

### Group A — Role-enforced (session role required)
sk.implement, sk.test, sk.review, sk.investigate
These branch on backend vs. frontend. Session role must be set before running.
NULL role → STOP. Do not proceed. Do not prompt for role inline — instruct user to run sk.session switch --role <role> first.
Role determines subagent_type: backend → SpecKit Backend Engineer Agent / QA Backend Agent; frontend → SpecKit Frontend Engineer Agent / QA Frontend Agent.

### Group B — Self-asserting (no session role needed)
sk.specify (po), sk.architecture, sk.datamodel, sk.contracts, sk.adr, sk.impact,
sk.knowledge-base (architect), sk.plan, sk.tasks, sk.ff, sk.ship (lead),
sk.security-audit (security), sk.uat (frontend-qa)
Skill declares its own subagent_type — session role not consulted.
MUST NOT read or write session.yaml role field. MUST NOT prompt user to switch role.
Read session.yaml for active_intent_id, active_unit_id, active_story_id only.

### Group C — Self-asserting with defined default
sk.clarify → SpecKit Architect Agent
sk.analyze → SpecKit Lead Agent
sk.verify → SpecKit Architect Agent
No session role needed. Skill operates under its declared default subagent_type.
MUST NOT read or write session.yaml role field. MUST NOT prompt user to switch role.
Read session.yaml for active_intent_id, active_unit_id, active_story_id only.

### Group D — Role-agnostic (no subagent)
sk.phr, sk.session, sk.init — no subagent_type, run inline in main conversation.

## Idempotency
Artifact exists → [REFINE MODE] update, never overwrite.
Artifact missing → [CREATE MODE] create from template.
Declare mode at start of every execution.

## Skills Architecture
sk.* skills live in .claude/skills/sk.*/
Each skill has:
  SKILL.md  — frontmatter (name, description, subagent_type, inject_files) + brief description
  prompt.md — full workflow

inject_files declares static file dependencies injected before agent execution.
Dynamic paths (story-{ID}.md, architecture.md) are resolved by the agent after reading session.yaml.

sk.ff is an orchestrator skill — it invokes sk.specify → sk.clarify → [sk.architecture] → sk.plan → sk.tasks in sequence via the Skill tool.

## Upstream Reference
upstream/ is a pattern reference archive — not executed at runtime.
spec-kit AI prompting patterns have been inlined into sk.* skills.
Do not invoke upstream shell scripts. Do not reference upstream-adapter.md for execution.
See upstream-adapter.md for the migration rationale and pattern source map.
