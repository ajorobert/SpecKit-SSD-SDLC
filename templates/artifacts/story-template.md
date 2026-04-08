---
id: {INTENT-CODE}-{UNIT-CODE}-{NNN}
intent: {INTENT-CODE}
unit: {INTENT-CODE}-{UNIT-CODE}
title: {title}
status: draft | ready | in-progress | testing | security-review | review | done
owner: null
checkpoint_mode: null   # autopilot | confirm | validate
checkpoint_status: null # null | approved
architecture-ref: null  # relative path to unit architecture.md
test-status: null       # null | pass | fail
security-status: null   # null | CLEAR | CONDITIONAL | BLOCKED
created: {date}
updated: {date}
branch: null
---

# Story: {title}

## User Story
<!-- REQUIRED FORMAT:
As a [role],
I want to [action],
So that [value or reason].
-->

## Acceptance Criteria
<!-- REQUIRED FORMAT: Use checklist format with BDD (Given/When/Then) syntax where applicable.
Example:
- [ ] **Scenario**: User logs in
  - Given the user is on the login page
  - When they enter valid credentials
  - Then they are redirected to the dashboard
-->

## Out of Scope
<!-- List explicit features, edge cases, or optimizations that are NOT part of this story to prevent scope creep. -->

## Notes
<!-- Any implementation hints, references to ADRs, linking to upstream specs, or open questions. -->
