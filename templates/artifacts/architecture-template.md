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
     REQUIRED: every write path must have an entry.
     Also declare per write path:
     - commandId deduplication: required | natural (document why it is naturally idempotent)
     - Outbox pattern: required | not-required (required only if handler publishes events AND modifies state) -->

## Failure Modes
<!-- DDIA Ch 8: per external dependency — what fails, timeout, fallback.
     Example:
     - payment-service: timeout 3s → return 503, do not debit; retry with idempotency key
     - inventory-service: unavailable → hold order in PENDING, process via queue
     REQUIRED: every external dependency must have an entry. -->

## External Dependencies
<!-- List every upstream service, database, or third-party API this unit depends on.
     REQUIRED: every entry here must have a corresponding Failure Mode entry below.
     Format:
     - {dependency-name}: {protocol} — {SLA / expected latency} — {data exchanged}
     Example:
     - payment-service: REST (internal) — p99 < 500ms — charge requests and confirmation receipts
     - postgres (orders-db): TCP — p99 < 10ms — order reads and writes
     - SendGrid: HTTPS (external) — best-effort — transactional email dispatch -->

## Security Approach
<!-- Auth model, data sensitivity, and encryption strategy for this unit.
     Example:
     - Auth: JWT bearer tokens validated on every request via auth-service; no local session state
     - Data sensitivity: order totals and line items are PII-adjacent; encrypted at rest (AES-256)
     - Transport: TLS 1.2+ enforced; no plaintext internal communication
     - Input validation: all mutation endpoints validate schema before processing -->

## Error Handling
<!-- Error propagation strategy: what errors are surfaced to callers vs. swallowed internally.
     Example:
     - Validation errors: 422 with field-level detail (never swallowed)
     - Upstream timeouts: 503 returned to caller; upstream retried once with idempotency key
     - Internal panics: logged at ERROR with trace; 500 returned with generic message (no stack leak)
     - Business rule violations: 409 with machine-readable error code (e.g. INSUFFICIENT_STOCK) -->
## Observability
<!-- Describe the observability strategy for this unit.
     Required:
     - Which events are logged at INFO level (significant business events)
     - Which external calls require duration metrics
     - What GET /health verifies (which dependencies are checked)
     Optional:
     - Domain-level metrics emitted (counters, gauges, histograms)
     - Key business operations instrumented as named spans
     - Alert thresholds for error rate or latency
     Idempotency observability (required if command handlers exist):
     - Metric: commands_duplicate_total{handler, reason}
     - Log: WARN on duplicate commandId with fields: handler, commandId, original_executed_at
     Example:
     - Logging: INFO on order placed/cancelled; WARN on payment retry; WARN on duplicate command rejected; ERROR on processor failure
     - Metrics: orders_created_total; payment_processing_duration_seconds; payment_errors_total; commands_duplicate_total
     - Health: GET /health checks payment-service reachability + database connection
     See observability-standards.md for required structured logging fields and idempotency metric labels. -->

## Stories Coverage
<!-- List every story delivered by this unit. Update as stories are added.
     Format: - [{story-id}] {title}: {one-line summary of what this story delivers in this unit}
     Example:
     - [INV-001-ORD-001] Create Order: POST /orders endpoint, validation, inventory reservation
     - [INV-001-ORD-002] Cancel Order: status transition to CANCELLED, inventory release -->

## Open Questions
