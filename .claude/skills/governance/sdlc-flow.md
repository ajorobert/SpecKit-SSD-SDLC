SDLC Flow
Read by: sk.ff, sk.verify

Phase Sequence

sk.impact        — assess blast radius before any new work
sk.specify       — capture intent, decompose to units and stories
sk.clarify       — resolve ambiguities (run before sk.architecture)
sk.architecture  — define service boundaries, contracts, domain model
sk.datamodel     — define data model for active unit
sk.contracts     — define API contracts for active unit
sk.plan          — technical implementation plan
sk.tasks         — actionable task breakdown
sk.implement     — execute tasks
sk.verify        — PASS/FAIL audit against quality gates
sk.test          — generate and run test suite (backend-qa | frontend-qa)
sk.security-audit — OWASP audit, secrets scan, dependency scan (security)

Shortcut: sk.ff
Runs phases 2→3→4→7→8 in sequence for standard features.
Pauses at each Confirm/Validate checkpoint.
Skips sk.architecture if checkpoint_mode is autopilot.

## Knowledge Base Usage Per Phase
sk.impact          → read tier 1 + relevant tier 2
sk.architecture    → read tier 1 + tier 2 + update tier 3
sk.implement       → read tier 1 + tier 2 + tier 3 before code
sk.test            → read tier 1 + tier 3 before generating tests
sk.security-audit  → read tier 3 before auditing
sk.knowledge-base  → run after first unit complete, update per ADR

Phase Ownership
sk.impact          → architect
sk.specify         → product owner + architect
sk.clarify         → product owner
sk.architecture    → architect
sk.datamodel       → architect + backend lead
sk.contracts       → architect + backend lead
sk.plan            → backend lead / frontend lead (per unit)
sk.tasks           → implementing engineer
sk.implement       → implementing engineer
sk.verify          → architect + lead engineer
sk.test            → backend-qa + frontend-qa
sk.security-audit  → security
