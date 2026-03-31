---
unit: {unit-id}
intent: {intent-id}
status: draft | approved
stories-covered: []
created: {date}
updated: {date}
---

# Architecture: {unit-name}

## Service Responsibility
## Bounded Context
## Communication Patterns
## Internal Components
## Data Flow
## Access Patterns
<!-- DDIA Ch 2-3: what queries does this data serve?
     List reads (query shape, frequency) and writes (rate, size, key distribution).
     Example:
     - Read: fetch order by ID (point lookup, high frequency)
     - Read: list orders by user (range scan, paginated)
     - Write: create order (low rate, must be atomic with inventory check) -->

## Consistency Requirements
<!-- DDIA Ch 9: per write path — strong | eventual | causal — with rationale.
     Example:
     - POST /orders → strong (inventory reservation must be linearizable)
     - PATCH /orders/{id}/status → eventual (status fanout to notifications ok)
     REQUIRED: every write path must have an entry. -->

## Failure Modes
<!-- DDIA Ch 8: per external dependency — what fails, timeout, fallback.
     Example:
     - payment-service: timeout 3s → return 503, do not debit; retry with idempotency key
     - inventory-service: unavailable → hold order in PENDING, process via queue
     REQUIRED: every external dependency must have an entry. -->

## External Dependencies
## Security Approach
## Error Handling
## Stories Coverage
## Open Questions
