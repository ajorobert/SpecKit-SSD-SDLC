Command Rules
Apply on every sk.* command.

Lock Protocol

1. Check .specify/state.lock
   - EXISTS: read contents, report to user, STOP
   - NOT EXISTS: create with {command, started_at}
2. Execute command
3. Update state.yaml (read → update → re-read to verify)
4. Delete .specify/state.lock
5. If interrupted: lock persists, user must run sk.reset-lock

Idempotency

- Artifact exists → [REFINE MODE] update, never overwrite
- Artifact missing → [CREATE MODE]
- Declare mode at start of every execution

Post-Execution Memory Updates

sk.plan, sk.architecture → update service-registry.md, domain-model.md if changed
sk.datamodel             → update domain-model.md
sk.contracts             → update service-registry.md
sk.adr                   → update architecture-decisions.md index

ADR Triggers
Suggest (never create without confirmation) when:
- Decision spans more than one service
- Real alternatives were considered
- Involves auth, payments, or security

PHR Triggers
Create automatically after:
- sk.architecture
- sk.implement when novel tradeoffs resolved
