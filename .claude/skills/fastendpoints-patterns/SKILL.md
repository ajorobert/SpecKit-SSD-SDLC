---
name: fastendpoints-patterns
description: |
  FastEndpoints v6 endpoint patterns for .NET 10 with Scalar OpenAPI, ErrorOr response mapping, FluentValidation, idempotency-key contract, request size + rate limits. Use for every HTTP entry point.
when_to_load:
  - Task mentions: endpoint, route, http, api, openapi, scalar
  - Files touched: any *Endpoint.cs, *Endpoint*.cs, Program.cs (only if reviewing endpoint discovery)
co_loads_with:
  - backend-feature-patterns (handler the endpoint dispatches to)
  - auth-patterns (authorization policy + IUserContext)
  - wolverine-patterns (IMessageBus injection)
---

# FastEndpoints Patterns

> Assumes FastEndpoints v6 or later. APIs referenced below (typed bases, throttle hooks, Summary class form) are v6 contracts.

## 1. Mental model

An endpoint is a thin HTTP adapter — it binds the request, dispatches to a handler, and maps the result to HTTP. Business logic lives in the handler (see `backend-feature-patterns` §3). One endpoint class = one HTTP operation.

This stack does **not** use MVC controllers — there is no `: ControllerBase`, no `[ApiController]`, no `[Authorize]` attribute. Reflexes from those patterns must be unlearned. FastEndpoints uses class-per-endpoint plus `Configure()` for policy declaration.

| Base class | Use for | HTTP shape |
|---|---|---|
| `Endpoint<TRequest>` | Mutations with no response body | POST/PUT/PATCH/DELETE → 204 (or 202) |
| `Endpoint<TRequest, TResponse>` | Mutations or queries with parameters and a response body | POST/PUT/GET → 200/201 |
| `EndpointWithoutRequest<TResponse>` | Queries with no parameters | GET → 200 |
| `EndpointWithoutRequest` | Health/ping endpoints with neither | GET → 200/204 |

The bare `Endpoint` class is forbidden unless the line above carries `// ENDPOINT: Untyped — REASON: <reason>` (file proxy, raw stream pass-through). CI parses these and emits a manifest of untyped endpoints.

## 2. File and folder layout

```
src/YourContext.Api/
  Features/
    Listings/
      Activate/
        ActivateListingEndpoint.cs   // : Endpoint<Request, Response>
        Request.cs                   // record with [FromRoute]/[FromBody]
        Response.cs                  // record (omit for 204 endpoints)
        Validator.cs                 // : Validator<Request> (request-shape only)
        Mapper.cs                    // static — Request↔Command, ErrorOr<T>→Response
        Summary.cs                   // : Summary<Endpoint> — Scalar reads this
  Validation/
    CommonRules.cs                   // shared FluentValidation extensions for THIS bounded context
  YourContextEndpointsMarker.cs      // empty class, used for assembly scanning
```

One `*.Api` project per bounded context — `YourContext.Api`, `Auth.Api`, `Search.Api`. Each exposes an empty marker class so the host registers FastEndpoints by referencing the marker types (modular monolith today, microservice split tomorrow — endpoint code never changes).

## 3. Endpoint shape — command-side

```csharp
namespace YourContext.Api.Features.Listings.Activate;

public sealed class ActivateListingEndpoint(IMessageBus bus) : Endpoint<Request, Response>
{
    public override void Configure()
    {
        // ENDPOINT: POST /api/v1/listings/{ListingId}/activate
        Post("/api/v1/listings/{ListingId}/activate");
        // AUTH: Policy CanActivateListing — see auth-patterns
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
        // IDEMPOTENCY: header read happens here, forwarded on the command — see §6
        var idem = HttpContext.Request.Headers.TryGetValue("Idempotency-Key", out var v) ? v.ToString() : null;
        var command = Mapper.ToCommand(req, idem);

        // Wolverine InvokeAsync — see wolverine-patterns §3
        var result = await bus.InvokeAsync<ErrorOr<ActivateListingResult>>(command, ct);
        await this.ToHttpResultAsync(result, Mapper.ToResponse, ct);
    }
}

public sealed record Request
{
    [FromRoute] public Guid ListingId { get; init; }
    [FromBody]  public Body Payload { get; init; } = new();
    public sealed record Body(Guid ActorId);
}

public sealed record Response(Guid ListingId, string Status);

public static class Mapper
{
    public static ActivateListingCommand ToCommand(Request r, string? idem) =>
        new(r.ListingId, r.Payload.ActorId, idem);
    public static Response ToResponse(ActivateListingResult r) =>
        new(r.ListingId, r.Status);
}
```

The endpoint reads the `Idempotency-Key` header, forwards it on the command, dispatches via `IMessageBus.InvokeAsync`, and maps the `ErrorOr<T>` to HTTP through the single extension method defined in §7. Endpoint code never builds a `ProblemDetails` by hand.

## 4. Endpoint shape — query-side

```csharp
namespace YourContext.Api.Features.Listings.GetDetail;

public sealed class GetListingDetailEndpoint(IMessageBus bus) : Endpoint<Request, Response>
{
    public override void Configure()
    {
        // ENDPOINT: GET /api/v1/listings/{ListingId}
        Get("/api/v1/listings/{ListingId}");
        // AUTH: Policy CanReadListing
        Policies("CanReadListing");
        Description(b => b.Produces<Response>(200).ProducesProblem(404));
    }

    public override async Task HandleAsync(Request req, CancellationToken ct)
    {
        var result = await bus.InvokeAsync<ErrorOr<ListingDetailDto>>(new GetListingDetailQuery(req.ListingId), ct);
        await this.ToHttpResultAsync(result, Mapper.ToResponse, ct);
    }
}

public sealed record Request { [FromRoute] public Guid ListingId { get; init; } }
```

Query endpoints follow the same dispatch + ErrorOr-mapping shape as command endpoints. The only difference is the verb and the lack of an idempotency-key read.

## 5. Validators

One validator per endpoint, living next to it. FastEndpoints discovers it via `Validator<TRequest>`.

**Split rule:** request-validator handles input *shape* (non-empty, length, regex); command-validator (lives in Application — see `backend-feature-patterns` §6) handles *business* rules. Never duplicate a rule across both — pick a side based on whether the rule is about syntax or semantics.

```csharp
public sealed class ActivateListingValidator : Validator<ActivateListingEndpoint.Request>
{
    public ActivateListingValidator()
    {
        RuleFor(x => x.ListingId).NotEmpty();
        RuleFor(x => x.Payload.ActorId).NotEmpty();
    }
}
```

Cross-cutting rules used by multiple endpoints in the same bounded context go in `Validation/CommonRules.cs` as FluentValidation extension methods.

## 6. Idempotency-Key contract (HTTP side)

Header: `Idempotency-Key: <ulid-or-uuid>`. Required on every state-mutating endpoint that creates or charges state (POST, plus PUT/PATCH/DELETE that have business-level retry implications); optional on safe verbs.

**Endpoint duties:**

1. Read the header.
2. Forward it on the command as `IdempotencyKey`.
3. The handler-side dedup logic lives in `backend-feature-patterns` §8.

**Failure modes** (mapped automatically by the ErrorOr→HTTP extension in §7):

| Condition | Error | HTTP |
|---|---|---|
| Missing header on a required endpoint | `Error.Validation("Http.IdempotencyKeyRequired")` | 400 |
| Replayed key with different fingerprint | `Error.Conflict("Http.IdempotencyKeyReused")` | 409 |
| In-flight replay (same key, same fingerprint, original still running) | `Error.Conflict("Http.IdempotencyInProgress")` | 409 |

```csharp
public override async Task HandleAsync(Request req, CancellationToken ct)
{
    // IDEMPOTENCY: read header; forward on command; handler enforces dedup
    if (!HttpContext.Request.Headers.TryGetValue("Idempotency-Key", out var key) || string.IsNullOrEmpty(key))
    {
        await this.ToHttpResultAsync<Response>(Error.Validation("Http.IdempotencyKeyRequired"), ct);
        return;
    }
    var result = await bus.InvokeAsync<ErrorOr<OrderPlacedResult>>(Mapper.ToCommand(req, key!), ct);
    await this.ToHttpResultAsync(result, Mapper.ToResponse, ct);
}
```

## 7. ErrorOr → HTTP mapping

A single extension method maps every `ErrorOr<T>` to HTTP + RFC 7807 ProblemDetails. Endpoints call it; they never construct ProblemDetails by hand. The implementation lives in `src/Shared.Web/Result/`; this skill specifies the contract.

ProblemDetails `type` URI: `https://errors.yourcompany.com/your-service/<error-code>` (Phase 0.1 convention). `<error-code>` is the dotted code from `ErrorOr.Error.Code` (e.g. `Listing.AlreadyActive`).

```csharp
namespace YourContext.Api.Http;

public static class ErrorOrHttpExtensions
{
    // Use when there is a typed response body to send on success
    public static Task ToHttpResultAsync<TResult, TResponse>(
        this IEndpoint endpoint,
        ErrorOr<TResult> result,
        Func<TResult, TResponse> map,
        CancellationToken ct)
    {
        if (!result.IsError)
            return endpoint.HttpContext.Response.SendAsync(map(result.Value), 200, cancellation: ct);
        return endpoint.SendProblemAsync(result.FirstError, ct);
    }

    // Use when the success path is 204 No Content
    public static Task ToHttpResultAsync(this IEndpoint endpoint, ErrorOr<Success> result, CancellationToken ct)
        => result.IsError
            ? endpoint.SendProblemAsync(result.FirstError, ct)
            : endpoint.HttpContext.Response.SendNoContentAsync(ct);

    private static Task SendProblemAsync(this IEndpoint endpoint, Error error, CancellationToken ct)
    {
        var (status, slug) = error.Type switch
        {
            ErrorType.Validation => (400, "validation"),
            ErrorType.NotFound   => (404, "not-found"),
            ErrorType.Conflict   => (409, "conflict"),
            ErrorType.Forbidden  => (403, "forbidden"),
            _                    => (500, "internal"),
        };
        var problem = new ProblemDetails
        {
            Status   = status,
            Title    = error.Description,
            Type     = $"https://errors.yourcompany.com/your-service/{error.Code}",
            Instance = $"urn:trace:{Activity.Current?.TraceId.ToString() ?? "none"}",
        };
        problem.Extensions["code"] = error.Code;
        return endpoint.HttpContext.Response.SendAsync(problem, status, cancellation: ct);
    }
}
```

Five `ErrorType` values cover the surface: `Validation`, `NotFound`, `Conflict`, `Forbidden`, `Failure` (the default fall-through → 500). Anything outside this set is a bug.

## 8. Scalar OpenAPI integration

Scalar is the OpenAPI UI in this stack — there is no Swagger UI. Each endpoint declares a nested `Summary` class (not the lambda overload). Scalar reads the resulting OpenAPI doc; route grouping comes from FastEndpoints' `Group()` for OpenAPI tags.

```csharp
public sealed class Summary : Summary<ActivateListingEndpoint>
{
    public Summary()
    {
        this.Summary       = "Activate a listing";
        this.Description   = "Transitions a listing from Draft to Active. Idempotent on (ListingId).";
        this.ExampleRequest = new ActivateListingEndpoint.Request { ListingId = Guid.NewGuid() };
        this.Response<ActivateListingEndpoint.Response>(200, "Listing activated");
        this.Response<ProblemDetails>(400, "Validation failure");
        this.Response<ProblemDetails>(404, "Listing not found");
        this.Response<ProblemDetails>(409, "Listing already active");
    }
}
```

Missing `Summary` class on a non-untyped endpoint is a CI failure. Generated OpenAPI must be usable by BFF/portal teams without hand-editing.

## 9. Rate limiting

Two options. Pick by whether the limit must be shared across instances.

- **Per-instance throttle** — `Throttle(hitLimit, durationSeconds)` (FastEndpoints built-in, in-memory). Use for abuse prevention: login burst, OTP request floods. Effective for "one client cannot hammer one pod"; ineffective for "tenant cannot exceed N requests/min across the fleet".
- **Shared-across-instances** — `IRateLimiter` adapter backed by a Redis sliding window (see `hybridcache-patterns` §10). Use for fairness and quota — anything advertised as a request rate must be measured against shared counters.

Decision rule: in-memory throttle for *abuse prevention*; `IRateLimiter` for *fairness/quota*. Throttle keys for the in-memory path follow the auth-aware precedence (`u:<user_id>` for authenticated; `t:<tenant_id>|ip:<ip>` for anonymous tenant-scoped; `ip:<ip>` last resort). Throttled responses MUST set `Retry-After` (seconds).

## 10. Request size, allowed verbs, CORS

- **Body size** — every endpoint accepting a body declares `MaxRequestBodySize(bytes)` inside `Configure()`. Defaults are too generous. Sensitive endpoints (login, OTP, password reset) cap at 10 KB; standard JSON write at 256 KB; bulk write at 1 MB (consider messaging instead). File upload sizes are per-endpoint and paired with virus scan (see `file-storage-patterns`).
- **Verb restriction** — explicit in `Configure()` via `Post(...)`, `Put(...)` etc. No catch-all verbs.
- **CORS** — registered as a FastEndpoints policy in the host composition; endpoints opt in by policy name.

## 11. Anti-patterns

- Business logic inside `HandleAsync` (anything beyond bind + dispatch + map).
- Reading `DbContext`, `HybridCache`, or repositories directly from the endpoint.
- Catching exceptions in the endpoint — let Wolverine middleware and ASP.NET Core handle them.
- Multiple commands dispatched from one endpoint — split into separate endpoints.
- Sharing a single DTO between the endpoint's `Response` and the Application layer's command result — keep Api-layer DTOs separate from Application-layer responses.
- `[Authorize]` attribute — FastEndpoints uses `.Policies(...)` / `.AllowAnonymous()` inside `Configure()`.
- FastEndpoints `Mapper<TRequest, TResponse, TEntity>` base class — it pulls the domain entity into the Api layer.
- In-memory throttle in production for fairness-style limits (multi-pod = N×limit leak).

## 12. Comment markers emitted by this skill

- `// ENDPOINT:` — route + verb on the line above `Post(...)` / `Get(...)` / etc.
- `// AUTH:` — authorization policy/role. For anonymous endpoints, use the exact form `// AUTH: Anonymous — REASON: <reason>` (CI parses this and emits a manifest).
- `// IDEMPOTENCY:` — the line that reads the `Idempotency-Key` header (or annotates the dedup contract on the endpoint).

The complete cross-skill comment-marker index lives in `backend-feature-patterns` §10.

## 13. References

- `backend-feature-patterns` §3, §5, §8 — handler shape, ErrorOr contract, idempotency handler-side.
- `wolverine-patterns` §3 — `IMessageBus.InvokeAsync` semantics.
- `auth-patterns` — policy registry, `IUserContext`, JWT validation.
- `hybridcache-patterns` §10 — `IRateLimiter` adapter, idempotency-key storage.
