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

Shortcut: sk.ff
Runs phases 2→3→4→7→8 in sequence for standard features.
Pauses at each Confirm/Validate checkpoint.
Skips sk.architecture if checkpoint_mode is autopilot.

Phase Ownership
sk.impact       → architect
sk.specify      → product owner + architect
sk.clarify      → product owner
sk.architecture → architect
sk.datamodel    → architect + backend lead
sk.contracts    → architect + backend lead
sk.plan         → backend lead / frontend lead (per unit)
sk.tasks        → implementing engineer
sk.implement    → implementing engineer
sk.verify       → architect + lead engineer
