# Skill Rules
Apply on every sk.* skill.

## Session Resolution
Every skill resolves context from .claude/session.yaml
If session.yaml role is null: STOP, instruct user to run sk.session start

Unit-level skills (sk.architecture, sk.datamodel, sk.contracts):
- Require active_unit_id set in session.yaml
- If null: instruct user to run sk.session focus --unit {unit-id}

Story-level skills (sk.plan, sk.tasks, sk.implement, sk.clarify):
- Require active_story_id set in session.yaml
- If null: instruct user to run sk.session focus --story {story-id}

## Test Role Routing
sk.test branches on session.yaml role:
- role = backend-qa → generate provider contract tests + integration tests
- role = frontend-qa → generate consumer contract tests + E2E tests + component tests
- role = other → STOP: "sk.test requires backend-qa or frontend-qa role"

## Security Role Gate
sk.security-audit requires role = security in session.yaml
Any other role → STOP: "sk.security-audit requires security role.
Run sk.session switch --role security"

## Idempotency
- Artifact exists → [REFINE MODE] update, never overwrite
- Artifact missing → [CREATE MODE]
- Declare mode at start of every execution

## Upstream Reference
.speckit/upstream/ is a pattern reference archive — not executed at runtime.
spec-kit AI prompting patterns have been inlined into sk.* skills.
Do not invoke upstream shell scripts. Do not reference upstream-adapter.md for execution.
See .specify/memory/upstream-adapter.md for migration rationale and pattern source map.

## Post-Execution Memory Updates
sk.plan, sk.architecture → update service-registry.md, domain-model.md if changed
sk.datamodel             → update domain-model.md
sk.contracts             → update service-registry.md
sk.adr                   → update architecture-decisions.md index

## ADR Triggers
Suggest (never create without confirmation) when:
- Decision spans more than one service
- Real alternatives were considered
- Involves auth, payments, or security
- Consistency model changes (strong ↔ eventual, or introducing eventual consistency for the first time)
- New partitioning or replication strategy adopted for a service or collection

## PHR Triggers
Create automatically after:
- sk.architecture
- sk.implement when novel tradeoffs resolved

## Knowledge Base Loading Order
For sk.implement, sk.test, sk.security-audit:
1. Read specs/knowledge-base.md (tier 1) if exists
2. Read specs/domains/{domain}/knowledge-base.md (tier 2) if exists
3. Read unit knowledge-base.md (tier 3) if exists
4. Then read code and detail files
Knowledge bases contain non-derivable context only.
They complement code reading — do not treat them as
a substitute for reading the actual implementation.

## Safety Restrictions (Pre-Tool Equivalents)
1. **No Direct Deletion:** Never directly delete files or use destructive shell commands (like `rm`, `del`, `Remove-Item`). If a file must be removed, use the archive workflow instead:
   `bash .claude/hooks/archive-file.sh "<relative-path>" "<reason for removal>"`
2. **Path Confinement:** All file modifications (edits/writes) MUST stay within the project root. Never attempt to read or modify external system directories (e.g., `/etc/`, `/usr/`, `C:\Windows`) or user home directories under any circumstances.
