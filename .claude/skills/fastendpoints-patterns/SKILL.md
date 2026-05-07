---
name: fastendpoints-patterns
description: "Load when: implementing or reviewing C# .NET 10 HTTP endpoints with FastEndpoints (v6+). URL-path versioning, feature folders, per-endpoint validators, policy-only auth, Result→ProblemDetails mapping (Ardalis.Result), per-bounded-context assemblies, redis-backed throttling with tenant-aware keys, idempotency-key contract, mandatory typed Summary for Swagger. References csharp-clean-arch (Result/CQRS), auth-patterns (Keycloak policies), observability-backend (span naming)."
---

# FastEndpoints Patterns

> **Assumes FastEndpoints v6 or later.** APIs and pipeline shapes referenced here (filters, throttle hooks, summary class form) are v6 contracts; some pre-v6 equivalents differ.

## Purpose
Production patterns for FastEndpoints in C# .NET 10 services. Every backend service and the BFF backend share this surface. Defines endpoint structure, request binding, validation, authorization, error mapping, throttling, idempotency, and OpenAPI generation so endpoints are uniform across bounded contexts and the Swagger doc stays honest.

This skill **references** rather than redefines:
* `csharp-clean-arch` for the Result pattern (`Ardalis.Result`), CQRS marker interfaces, DI rules, async correctness.
* `auth-patterns` for Keycloak realm/client model and the policy registry.
* `observability-backend` for HTTP server span naming and required RED metrics (auto-instrumented).
* `messaging-patterns` for "endpoint dispatches a MediatR command/query" mechanics and outbox idempotency.
* `redis-patterns` for throttle and idempotency-key storage topology.

**Guiding principle:** rules and contracts live in this skill. One-time infrastructure code (filter implementations, registration boilerplate) lives in the codebase — usually `src/Shared.Web/` — referenced from here by path only.

## Core Rules

### Endpoint Base Classes
Every endpoint inherits from one of these. The class declaration alone tells you the contract.

| Base class | Use for | HTTP shape |
|---|---|---|
| `Endpoint<TRequest>` | Mutations with no response body | POST/PUT/PATCH/DELETE → 204 (or 202) |
| `Endpoint<TRequest, TResponse>` | Mutations or queries with parameters and a response body | POST/PUT/GET → 200/201 with body |
| `EndpointWithoutRequest<TResponse>` | Queries with no parameters at all | GET → 200 with body |
| `EndpointWithoutRequest` | Health/ping/status endpoints with neither | GET → 200/204 |

**The bare `Endpoint` class is forbidden** *unless* the endpoint declares an opt-out comment on the line above the class:

```csharp
// ENDPOINT: Untyped — REASON: file proxy with raw stream pass-through
public sealed class ProxyEndpoint : Endpoint
```

CI parses these comments and surfaces a manifest of untyped endpoints. The exemption exists for genuine streaming/proxy cases; everything else uses a typed base.

### URL-Path Versioning
* Versions live in the URL path: `/api/v1/listings`, `/api/v2/listings`. Never header-based.
* Each version is a distinct endpoint class (`v1.CreateListingEndpoint`, `v2.CreateListingEndpoint`) — not flag-switching inside one class.
* Version numbers match integration contract versions used by `messaging-patterns` (e.g., `v1.ListingActivated` event ↔ `/api/v1/listings/{id}/activate` endpoint).
* Deprecating a version: mark with `Description(b => b.Deprecated())` for at least one release before removing.

### Feature Folder Layout
One folder per use case. Up to five files; omit any that don't apply (e.g., no `Response.cs` for a 204 endpoint, no `Request.cs` for `EndpointWithoutRequest`):

```
src/Marketplace.Api/
  Features/
    Listings/
      Activate/
        ActivateListingEndpoint.cs   // : Endpoint<Request>
        Request.cs                   // record with [FromRoute]/[FromBody] etc.
        Response.cs                  // record (omit for 204 endpoints)
        Validator.cs                 // : Validator<Request>  (omit if no Request)
        Mapper.cs                    // static — Request→Command, Result→Response
  Validation/
    CommonRules.cs                   // shared FluentValidation extensions for THIS bounded context
  MarketplaceEndpointsMarker.cs      // empty class, used for assembly scanning
```

Rationale: feature folders mirror MediatR command/query naming, keep change-locality tight (one feature → one folder), and let CODEOWNERS files target single use cases.

### Per-Bounded-Context Assemblies + Marker Class
* **One `*.Api` project per bounded context** — `Marketplace.Api`, `Auth.Api`, `Search.Api`.
* Each `*.Api` project exposes an empty marker class:

```csharp
// src/Marketplace.Api/MarketplaceEndpointsMarker.cs
namespace Marketplace.Api;
public sealed class MarketplaceEndpointsMarker { /* empty */ }
```

* The host registers FastEndpoints by referencing the marker types — see `Program.cs` example below.

This works for both **modular-monolith hosting** (one host references many `*.Api` projects) and a **future microservice split** (each host references one `*.Api` project) — endpoint code never changes.

### Request Binding — Explicit Attributes Required
Every Request property MUST carry an explicit binding attribute: `[FromRoute]`, `[FromQuery]`, `[FromBody]`, `[FromHeader]`, or `[FromForm]`. The default polymorphic binding is forbidden.

**The binding attribute MUST match the OpenAPI parameter location.** A `[FromRoute]` property shows as a path parameter in the generated doc; `[FromQuery]` shows as a query parameter. Mismatches between attribute and OpenAPI doc are a CI failure. This keeps the Swagger doc honest.

```csharp
public sealed record Request
{
    [FromRoute] public Guid ListingId { get; init; }
    [FromQuery] public bool ForceReindex { get; init; }
    [FromBody]  public Body Payload { get; init; } = new();

    public sealed record Body(string Reason, DateTimeOffset EffectiveAt);
}
```

### Validation — Per-Endpoint with Shared Common Rules
* **One validator per endpoint** in the feature folder. Validators are not shared across endpoints — different endpoints have different invariants even when their Requests look similar.
* **Cross-cutting rules** (e.g., "tenant ID must be a non-empty Guid", "phone must match E.164") live in `Validation/CommonRules.cs` per bounded context as **FluentValidation extension methods**.
* Validation runs automatically before `HandleAsync` — failures produce a `400 ProblemDetails` via the `Result→ProblemDetails` mapping below. No need to call `await ValidateAsync()` in the handler.
* **Scope of CommonRules**: rules used by only one bounded context live in that context's `Validation/CommonRules.cs`. Promote to a shared library only when ≥2 contexts use the *identical* rule. Premature sharing creates coupling between contexts.

### Authorization — Policy-Only
**Endpoints declare `Policies(...)`. Never `Roles(...)`, never `Permissions(...)`, never inline role/permission checks.** All authorization logic lives in policy handlers — see `auth-patterns` for the Keycloak realm/client/policy registry and the policy/requirement/handler shape.

```csharp
public override void Configure()
{
    Post("/api/v1/listings/{ListingId}/activate");
    Policies("CanActivateListing");
}
```

Each service has **one policy registry** (`AuthorizationPolicies.cs`) where the policy → requirement → handler mapping is defined (registry implementation detail belongs in `auth-patterns`). The endpoint references the policy name; everything else is in the registry. This keeps the auth model in one place when it changes (and it will).

### Anonymous Endpoints — Mandatory Justification Comment
Every `AllowAnonymous()` line MUST carry a structured comment **on the line directly above**:

```csharp
public override void Configure()
{
    Post("/api/v1/auth/login");
    // AUTH: Anonymous — REASON: login endpoint, JWT issued on success
    AllowAnonymous();
}
```

Format is **exact**: `// AUTH: Anonymous — REASON: <reason>`. CI parses this format and emits a manifest of every anonymous endpoint with its justification — security review reads this manifest, not individual files. Missing or malformed comment is a CI failure.

### Result→HTTP Mapping (`SendResultAsync<T>`)
Endpoints return `Ardalis.Result.Result<T>` from MediatR command/query handlers. A single shared extension method maps `ResultStatus` to HTTP + RFC 7807 ProblemDetails. **Endpoint code never builds a `ProblemDetails` by hand.**

| `ResultStatus` | HTTP | ProblemDetails `type` slug |
|---|---|---|
| `Ok` / `Created` | 200 / 201 | (no problem doc — body is the response) |
| `NoContent` | 204 | — |
| `NotFound` | 404 | `not-found` |
| `Invalid` | 400 | `validation` (with `errors` map of field → messages) |
| `Conflict` | 409 | `conflict` |
| `Forbidden` | 403 | `forbidden` |
| `Unauthorized` | 401 | `unauthorized` |
| `Error` / `CriticalError` | 500 | `internal` |

The six `Result.Failure` codes are the canonical taxonomy: `NotFound`, `Validation`, `Conflict`, `Forbidden`, `Unauthorized`, `Unexpected`. No other failure shapes exist.

**`type` URI**: fully-qualified, configurable per service via `appsettings.json`:

```json
"ProblemDetails": { "BaseUri": "https://errors.yourcompany.com/marketplace" }
```

Final URI is `{BaseUri}/{slug}`. Reason: when a BFF or third-party aggregates errors from multiple services, fully-qualified URIs disambiguate. Each bounded context owns its error namespace.

**`instance`**: set to `urn:trace:<traceId>` so a user reporting "instance: `urn:trace:7f3a9b…c4`" lets ops jump straight to the trace in Jaeger. Implementation pulls `Activity.Current?.TraceId`.

**Implementation lives in** `src/Shared.Web/Result/SendResultAsync.cs` (one-time infra; do not duplicate per service).

### Throttling — Redis-Backed, Tenant-Aware
* **In-memory throttling is forbidden in production.** A multi-pod service with in-memory throttling lets a client get N×pods requests, which is not the limit you advertised.
* Production throttle storage is **Redis** — see `redis-patterns` for the primary/replica/sentinel topology and key conventions.
* **Throttle keys must be scoped correctly** — IP-only keys are defeated by NAT (offices, mobile carriers, corporate VPNs share a single egress IP). Key precedence:

| Endpoint type | Throttle key | Rationale |
|---|---|---|
| Authenticated | `u:<user_id>` | Owns the action; survives IP changes (mobile roaming, VPN) |
| Anonymous, tenant-scoped | `t:<tenant_id>\|ip:<ip>` | NAT'd users share an IP; pair with tenant when known |
| Anonymous, cross-tenant (e.g., signup) | `ip:<ip>` only — and rate generously | Last resort; tighter limits at the gateway |

* **Throttled responses MUST set `Retry-After`** (seconds). RFC 6585/9110 — clients use this to back off intelligently. FastEndpoints' default doesn't always set it; the shared middleware backstop ensures it.
* Throttle policies live on **sensitive endpoints only**: login, OTP request/verify, password reset, signup, expensive search. Coarse rate limits are upstream at the gateway/BFF.

**Implementation lives in** `src/Shared.Web/Throttling/` (key generator + Redis storage adapter + Retry-After middleware).

### Mappers — Static, Clean-Arch-Compliant
The `Mapper.cs` in each feature folder is a **static class** with two methods: `ToCommand(Request)` and `ToResponse(Result.Value)`.

* **Never** use FastEndpoints' `Mapper<TRequest, TResponse, TEntity>` base class — it pulls the entity into the API layer and leaks the domain (Clean Architecture violation).
* The API layer maps Request → MediatR command/query (DTO). It never sees domain entities. The handler (Application layer) maps command → entity internally.
* Static mapping is trivially testable, has zero DI dependencies, and forces the team to keep mappings dumb.

### Swagger / OpenAPI — Mandatory Typed Summary
Every endpoint MUST declare a nested `Summary` class (the class form, not the lambda overload). It forces structured documentation:

```csharp
public sealed class Summary : Summary<ActivateListingEndpoint>
{
    public Summary()
    {
        this.Summary = "Activate a listing";
        this.Description = "Transitions a listing from Draft to Active. Idempotent on (ListingId).";
        this.Response<Response>(200, "Listing activated");
        this.Response<ProblemDetails>(404, "Listing not found");
        this.Response<ProblemDetails>(409, "Listing already active");
        this.Response<ProblemDetails>(400, "Validation failure");
    }
}
```

* **Missing Summary class is a CI failure.** Generated OpenAPI must be usable by BFF/portal teams without hand-editing.
* One Swagger doc per service per version (`/swagger/v1/swagger.json`, `/swagger/v2/swagger.json`).
* `NSwag` is the OpenAPI generator (FastEndpoints' default).

### HTTP Method Selection and Idempotency
**Idempotency is the rule that actually matters.** Verb selection is downstream of it.

| Verb | Idempotency contract | Use for |
|---|---|---|
| `GET` | Idempotent + safe (no side effects) | Queries |
| `PUT` | **MUST be idempotent.** Same request body → same final state, no matter how many times sent | Full replacement of an identifiable resource |
| `DELETE` | **MUST be idempotent.** Second DELETE of a missing resource returns `204` or `404`, never `500`. Always returns `204` regardless of underlying strategy — the client doesn't need to know whether it was soft, hard, or archived | The deletion *strategy* is a per-aggregate Domain decision (see below) |
| `PATCH` | Idempotent unless explicitly documented otherwise (e.g., `?op=increment`). Default to JSON Merge Patch (RFC 7396) — naturally idempotent. JSON Patch (RFC 6902) supports non-idempotent ops (`add` to an array) — use only when payload structure demands it, and document the non-idempotency in the `Summary` | Partial update |
| `POST` | **NOT idempotent by HTTP contract.** Network retry of a POST can create duplicate state (the "double-charged customer" bug). MUST opt in to idempotency via the `Idempotency-Key` header pattern below for any POST that mutates state | Create, or non-idempotent action without a natural identity |

State-mutating "actions" that don't fit CRUD: `POST /api/v1/listings/{id}/activate` (subresource verb). Never invent custom HTTP verbs.

**Deletion strategy is a Domain decision, not an HTTP one.** The DELETE endpoint always returns `204`; what happens behind it is per-aggregate and documented in the aggregate's Domain project README. Three valid strategies:

| Strategy | When | Examples |
|---|---|---|
| **Soft delete** (tombstone column / `DeletedAt`) | Aggregates with audit or recovery value. Pair with a separate hard-delete code path for GDPR right-to-erasure | Listings, Orders, Users, Accounts |
| **Hard delete** (row removed) | Aggregates with no historical value | OtpCodes, ephemeral session state, expired tokens, idempotency-key replay records |
| **Archive** (move to separate table or cold storage) | Aggregates needing long retention but rarely queried | Closed orders > 7 years old, completed audit log entries, fulfilled invitations |

Document the chosen strategy in `src/{Aggregate}.Domain/README.md` with one sentence per aggregate. The HTTP layer is intentionally ignorant — `DELETE /api/v1/orders/{id}` returns `204` whether the order was tombstoned, archived, or removed. This keeps the API contract stable while the domain evolves.

### Response Caching Headers (GET endpoints)
By default, **caching is handled at the gateway/CDN layer**, not at endpoint level — services emit no `Cache-Control` and let the gateway tier decide based on path patterns. Endpoints opt in to setting their own cache headers only when the gateway can't make the decision (resource-specific freshness, conditional GET).

When an endpoint does set its own cache headers, follow this contract:

| Resource shape | Headers to set | Example |
|---|---|---|
| Immutable (content-addressed, e.g., signed file URLs, version-pinned config) | `Cache-Control: public, max-age=31536000, immutable` | Static asset metadata, signed URL responses |
| Slowly-changing public data (catalog, taxonomy, public listings) | `Cache-Control: public, max-age=60, stale-while-revalidate=300` | Public listing detail, category tree |
| User-specific data | `Cache-Control: private, max-age=0, must-revalidate` + `ETag` | User profile, account settings |
| Conditional GET (any of the above) | `ETag: "<weak-or-strong-hash>"` and/or `Last-Modified: <RFC7231-date>`; honour `If-None-Match` / `If-Modified-Since` returning `304 Not Modified` | Detail endpoints with frequent polling |

Rules:
* **Never** mix `Cache-Control: public` with auth-bearing responses — leaks across users at intermediate caches.
* `ETag` is preferred over `Last-Modified` (sub-second precision; survives clock skew). Use weak ETags (`W/"…"`) when bytes may differ but semantics don't.
* If the endpoint participates in the `Idempotency-Key` flow (POST), caching headers don't apply — that's a different mechanism.
* Document the decision in the endpoint's `Summary` — readers shouldn't have to grep for header writes to understand caching behaviour.

**Implementation lives in** `src/Shared.Web/Caching/` — extension methods like `this.SetEtag(value)` and `this.NotModifiedIfMatches(etag)` keep endpoint code one-line.

If your stack handles caching purely at gateway/CDN today, this section is a forward-looking convention; endpoints simply don't set the headers and the gateway rules apply.

### `Idempotency-Key` Header Pattern (mandatory on state-mutating POST)
Every POST that creates or charges state — payments, order placement, outbox-published integration commands, account creation, anything that costs money or sends a notification — MUST accept an `Idempotency-Key` header. Stripe, Square, AWS, and IETF (`draft-ietf-httpapi-idempotency-key-header`) all converged on this; we follow the same convention.

**Contract:**
1. Client generates a UUID v4 per logical operation (NOT per retry — same key is reused on retry).
2. Server stores `(idempotency_key, request_fingerprint, response_status, response_body, expires_at)` in Redis with a **24-hour TTL**.
3. On request:
   - **Key not seen** → execute, persist response under the key, return.
   - **Key seen + same fingerprint** → return the stored response verbatim. Do NOT re-execute. If the original processing is still in flight, block briefly (≤2s) on a per-key Redis lock; if still in flight after the wait, return `409 Conflict` with `type: <base>/idempotency-in-progress`.
   - **Key seen + different fingerprint** → return `422 Unprocessable Entity` with `type: <base>/idempotency-key-reused`. The client is reusing a key for a different operation — that's a client bug, not a retry.
4. **Fingerprint** = SHA-256 of (route template + sorted request body bytes + auth subject). Detects accidental key reuse without storing the full request.
5. **Storage** is Redis (see `redis-patterns`). Key format: `idem:{service}:{user_or_tenant}:{uuid}`.
6. **TTL: 24 hours** by default. Long enough for retries, short enough that key collisions are negligible.
7. **The handler logic itself must remain idempotent at the domain layer** — database unique constraint on natural key, outbox dedup on `MessageId`. The header is belt-and-braces — it stops duplicate work cheaply, but doesn't replace domain idempotency. **Both layers required.**

**Endpoints that MUST require `Idempotency-Key`:**
* Anything publishing an integration event (see `messaging-patterns` outbox)
* Payments, charges, refunds
* Order/booking placement
* Account creation, invitation sending
* Any endpoint that triggers email/SMS/push to an external party

Missing header on a required endpoint → `400 Bad Request` with `type: <base>/idempotency-key-required`.

**Endpoints that should NOT require `Idempotency-Key`:**
* Pure queries (GET — wrong verb anyway)
* PUT / DELETE — already idempotent by contract
* POST that's truly safe to repeat (extremely rare; document the reasoning)

**Implementation lives in** `src/Shared.Web/Idempotency/` (filter + attribute + Redis storage). Endpoints opt in via attribute — see usage snippet under Patterns.

The feature flag rule of thumb: **if you'd page someone over a duplicate, require the key.**

### Cancellation Tokens
Every `HandleAsync` MUST accept a `CancellationToken` parameter and propagate it to **every** awaited call — `mediator.Send`, EF Core / Dapper queries, outbound `HttpClient` calls, Redis operations.

```csharp
public override async Task HandleAsync(Request req, CancellationToken ct)
{
    var result = await mediator.Send(Mapper.ToCommand(req), ct); // ct propagated
    await this.SendResultAsync(result, Mapper.ToResponse, ct);    // ct propagated
}
```

CI rule: a `HandleAsync` body that calls an awaitable method without passing `ct` is a failure. Cancellation is non-negotiable for graceful shutdown, request timeout, and back-pressure under load.

### Request Size Limits
Endpoints accepting a body MUST declare an explicit size limit via `MaxRequestBodySize(bytes)` inside `Configure()`. Defaults are too generous.

```csharp
public override void Configure()
{
    Post("/api/v1/listings");
    MaxRequestBodySize(256 * 1024); // 256 KB
}
```

| Endpoint type | Max body size |
|---|---|
| Sensitive (login, OTP, password reset) | **10 KB** |
| Standard JSON write (CRUD on a single aggregate) | 256 KB |
| Bulk write (batch create/update) | 1 MB — consider whether messaging/outbox is a better fit |
| File upload | per-endpoint declared, paired with virus-scan gate (see `file-storage-patterns`) |

A request that exceeds the limit returns `413 Payload Too Large` (handled by ASP.NET Core middleware; no endpoint code needed). Size limits guard against accidental and adversarial DoS through request body inflation.

### `Configure()` Call Ordering
For consistency and review-ability, calls inside `Configure()` follow this order:

```csharp
public override void Configure()
{
    // 1. HTTP verb + route
    Post("/api/v1/listings/{ListingId}/activate");

    // 2. Authorization (Policies / AllowAnonymous with REASON comment)
    Policies("CanActivateListing");

    // 3. Throttling
    Throttle(hitLimit: 30, durationSeconds: 60);

    // 4. Request size limit
    MaxRequestBodySize(256 * 1024);

    // 5. OpenAPI hints — chain Produces / ProducesProblem on a single Description call
    Description(b => b
        .Produces<Response>(200)
        .ProducesProblem(404)
        .ProducesProblem(409));
}
```

Reviewers can scan endpoints quickly because every `Configure()` block reads top-to-bottom in the same shape. CI does not enforce this (style, not safety), but `sk.review` flags violations.

## Patterns / Examples

### Endpoint — minimal canonical form (showing how the pieces connect)
The full forms (Validator, Summary, Response, Mapper) are specified by the rules above. This snippet shows only the wiring: Endpoint → Mapper → MediatR → SendResultAsync.

```csharp
namespace Marketplace.Api.Features.Listings.Activate;

public sealed class ActivateListingEndpoint(ISender mediator)
    : Endpoint<Request, Response>
{
    public override void Configure()
    {
        Post("/api/v1/listings/{ListingId}/activate");
        Policies("CanActivateListing");
        Throttle(hitLimit: 30, durationSeconds: 60);
        MaxRequestBodySize(256 * 1024);
        Description(b => b
            .Produces<Response>(200)
            .ProducesProblem(404)
            .ProducesProblem(409));
    }

    public override async Task HandleAsync(Request req, CancellationToken ct)
    {
        var result = await mediator.Send(Mapper.ToCommand(req), ct);
        await this.SendResultAsync(result, Mapper.ToResponse, ct);
    }
}
```

The companion files (`Request.cs` with `[FromRoute]`/`[FromBody]`, `Validator.cs` composing `CommonRules`, `Mapper.cs` static with `ToCommand`/`ToResponse`, `Summary.cs` with the typed summary class) follow the rules above — see existing endpoints under `src/Marketplace.Api/Features/` for working references.

### Anonymous endpoint — minimal form
```csharp
public override void Configure()
{
    Post("/api/v1/auth/login");
    // AUTH: Anonymous — REASON: login endpoint, JWT issued on success
    AllowAnonymous();
    Throttle(hitLimit: 5, durationSeconds: 60);
    MaxRequestBodySize(10 * 1024); // 10 KB cap
}
```

### Idempotency-Key — endpoint opt-in
```csharp
[RequiresIdempotencyKey] // from src/Shared.Web/Idempotency/
public sealed class PlaceOrderEndpoint(ISender mediator) : Endpoint<Request, Response>
{
    public override void Configure()
    {
        Post("/api/v1/orders");
        Policies("CanPlaceOrder");
        MaxRequestBodySize(256 * 1024);
    }

    public override async Task HandleAsync(Request req, CancellationToken ct)
    {
        var result = await mediator.Send(Mapper.ToCommand(req), ct);
        await this.SendResultAsync(result, Mapper.ToResponse, ct);
    }
}
```

The filter in `src/Shared.Web/Idempotency/` handles header validation, fingerprint computation, Redis lookup, per-key locking, and response replay — endpoint code stays clean.

### Host registration (`Program.cs`) — marker-class shape
```csharp
builder.Services.AddFastEndpoints(o => o.Assemblies =
[
    typeof(Marketplace.Api.MarketplaceEndpointsMarker).Assembly,
    typeof(Auth.Api.AuthEndpointsMarker).Assembly,
    typeof(Search.Api.SearchEndpointsMarker).Assembly,
]);
// Per-version SwaggerDocument(...) calls + UseFastEndpoints pipeline configuration
// live in src/Shared.Web/Hosting/FastEndpointsHost.cs.
```

Full Swagger setup, Result→ProblemDetails wiring, throttle storage registration, and idempotency filter wiring are factored into `src/Shared.Web/Hosting/` extension methods so each service host is ~20 lines of `Add*` calls, not boilerplate.

## CI Enforcement (mandatory checks)
A Roslyn analyzer or grep-based CI check enforces:

1. **Bare `Endpoint` class** — every endpoint inherits one of the four typed bases, or carries a `// ENDPOINT: Untyped — REASON: <reason>` comment. CI generates a manifest of untyped endpoints.
2. **Every Request property has a `[From*]` attribute** — and the attribute matches the OpenAPI parameter location in the generated doc.
3. **No `Roles(...)` or `Permissions(...)` calls** — only `Policies(...)`.
4. **Every `AllowAnonymous()` call has a preceding `// AUTH: Anonymous — REASON: ...` comment** in the exact format. CI generates a manifest of anonymous endpoints + reasons; security review reads the manifest.
5. **Every endpoint has a nested `Summary` class.**
6. **No in-memory throttle storage registered in non-Development environments** — check `Shared.Web/Hosting` extension calls and any service-specific overrides for `IThrottleStorage` registrations. Redis-backed storage is the only allowed implementation outside `Development`.
7. **No FastEndpoints `Mapper<,,>` base class usage** anywhere.
8. **`SendResultAsync` is the only path to writing a typed response body** in endpoint handlers — no direct `HttpContext.Response.WriteAsJsonAsync` from `HandleAsync`. The rule is narrowly about *typed body writes*; the following paths are NOT subject to it and operate freely: (a) header-only operations including `304 Not Modified` returns and ETag/Last-Modified setters from `src/Shared.Web/Caching/` (e.g., `this.SetEtag(...)`, `this.NotModifiedIfMatches(...)`); (b) **streaming endpoints** (file downloads, Server-Sent Events, raw byte streams), which MUST declare `// STREAM: <reason>` on the line above the streaming write call. CI manifests streaming exemptions the same way as `AUTH: Anonymous`.
9. **State-mutating POSTs require `[RequiresIdempotencyKey]`** — every endpoint inheriting `Endpoint<T>` or `Endpoint<T,R>` whose `Configure()` calls `Post(...)` MUST carry the attribute, unless the class declares `// IDEMPOTENCY: Not required — REASON: <reason>` (rare; PR-justified). PUT and DELETE are exempt (idempotent by HTTP contract).
10. **`HandleAsync` propagates `CancellationToken`** — any awaitable call inside `HandleAsync` that has a `CancellationToken` overload MUST receive `ct`. Calls without `ct` are a CI failure.

## When to Use
* Adding a new HTTP endpoint to a service or BFF
* Adding a new bounded-context `*.Api` project
* Reviewing a backend PR that adds or changes endpoints
* Designing a new API version (v1 → v2) for an existing bounded context
* Configuring throttling, idempotency, or request size limits on an endpoint

## When NOT to Use
* MediatR command/query handler implementation — see `csharp-clean-arch`
* Keycloak realm/client/role modeling, policy registry implementation, requirement/handler shape — see `auth-patterns`
* Background job or message consumer endpoints — those are not HTTP; see `messaging-patterns`
* Outbound HTTP calls (BFF → service, service → external) — covered by `bff-patterns` for aggregation flows
* gRPC endpoints — not in scope
