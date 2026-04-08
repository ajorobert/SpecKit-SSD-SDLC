---
id: {INTENT-CODE}-{UNIT-CODE}
intent: {INTENT-CODE}
title: {title}
status: draft | active | complete
created: {date}
updated: {date}
---

# Unit: {title}

## Owns
<!-- List the specific domains, data structures, and behaviors this unit is responsible for.
Example:
- User schemas and Database tables for Users
- Credential hashing and validation logic
-->

## Bounded Context
<!-- Define the boundaries of this unit. What lives completely inside? What boundary must not be crossed without an API contract?
Example: Auth unit does not know about permissions/billing, it only verifies identity. -->

## Dependencies
<!-- List external systems, databases, or other units this unit relies on to function.
Example:
- Postgres Database (primary store)
- Email Service (for password resets)
- INTENT-OTHER-01 (API contract reliance)
-->

## Stories
<!-- List the discrete User Stories (-NNN) required to implement this unit.
Example:
- INTENT-UNIT-001: Implement JWT generation
- INTENT-UNIT-002: Create login endpoint
-->
