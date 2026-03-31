SDLC Flow
Read by: sk.ff, sk.verify

Phase Sequence

[OPTIONAL] sk.office-hours  — validate product idea or feature approach before spec (po/architect)
sk.impact        — assess blast radius before any new work
sk.specify       — capture intent, decompose to units and stories
sk.clarify       — resolve ambiguities (run before sk.architecture)
[OPTIONAL] sk.plan-eng-review — validate architecture against existing services (architect)
sk.architecture  — define service boundaries, contracts, domain model
sk.datamodel     — define data model for active unit
sk.contracts     — define API contracts for active unit
sk.plan          — technical implementation plan
sk.tasks         — actionable task breakdown
sk.implement     — execute tasks
sk.review        — spec-aware code review: bounded context + contracts + ADRs (backend/frontend)
sk.verify        — PASS/FAIL audit against quality gates
sk.test          — generate and run test suite (backend-qa | frontend-qa)
sk.qa            — browser acceptance testing against AC (frontend-qa only)
sk.security-audit — OWASP + STRIDE audit, secrets scan, dependency scan (security)
sk.investigate   — [if blocked] spec-aware root-cause debugging (backend/frontend)
sk.ship          — quality-gated release via gstack (lead)

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
sk.office-hours    → po + architect (optional)
sk.impact          → architect
sk.specify         → product owner + architect
sk.clarify         → product owner
sk.plan-eng-review → architect (optional)
sk.architecture    → architect
sk.datamodel       → architect + backend lead
sk.contracts       → architect + backend lead
sk.plan            → backend lead / frontend lead (per unit)
sk.tasks           → implementing engineer
sk.implement       → implementing engineer
sk.review          → backend / frontend engineer
sk.verify          → architect + lead engineer
sk.test            → backend-qa + frontend-qa
sk.qa              → frontend-qa
sk.security-audit  → security
sk.investigate     → backend / frontend engineer
sk.ship            → lead
