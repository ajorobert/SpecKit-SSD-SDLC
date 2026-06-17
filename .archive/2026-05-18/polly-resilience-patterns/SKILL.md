---
name: polly-resilience-patterns
description: |
  HTTP resilience for .NET 10 via Polly v8 (Microsoft.Extensions.Http.Resilience). Covers standard + custom resilience pipelines, retry/circuit-breaker/timeout/bulkhead composition, idempotency-aware retry rules, DelegatingHandler chain order with M2M token attachment, transient-vs-permanent error mapping, OTel instrumentation. Use for every outbound HTTP call from this service.
when_to_load:
  - Task mentions: resilience, polly, retry, circuit breaker, timeout, bulkhead, transient, httpclient, outbound, ihttpclientfactory
  - Files touched: any AddHttpClient(...) registration, any custom DelegatingHandler, any external-API adapter class
co_loads_with:
  - keycloak-patterns (M2M DelegatingHandler chain order)
references:
  - elasticsearch-patterns (ES HTTP client uses this stack)
  - file-pipeline-patterns (SeaweedFS + nClam HTTP calls)
  - wolverine-patterns (Wolverine handler retry is separate — message-level vs HTTP-level)
  - observability-backend (OTel auto-instrumentation — Phase 5 placeholder)
---

# Polly Resilience Patterns

## 1. Mental model

Two retry layers in this stack:

- **HTTP-level (this skill):** Polly v8 via `Microsoft.Extensions.Http.Resilience`, attached to every outbound `HttpClient`.
- **Message-level (`wolverine-patterns §9`):** Wolverine handler-level retries on `Handle` failures.

**Rule:** HTTP retry handles transient network failures; message retry handles transient handler-side failures (DB temporary, ES rejected-due-to-load). They compose — a message handler that fails because an HTTP call exhausted retries gets re-delivered by Wolverine. They are complementary, not redundant.

**Canonical pipeline composition** (outermost → innermost):

```
[outer] Total request timeout
          │
          ▼
        Bulkhead (concurrency limiter)
          │
          ▼
        Circuit breaker
          │
          ▼
        Retry
          │
          ▼  per-attempt timeout
        HTTP call
```

## 2. Default: standard resilience pipeline

`AddStandardResilienceHandler()` covers most outbound calls — 3 retries with jittered exponential backoff, 30s per-attempt timeout, 100s total timeout, circuit breaks at 10% failure rate.

```csharp
namespace YourContext.Infrastructure.Http;

public static class HttpClientRegistration
{
    public static IServiceCollection AddYourContextHttpClients(this IServiceCollection services)
    {
        // RESILIENCE: standard pipeline — defaults cover most upstreams
        services.AddHttpClient<IPricingApiClient, PricingApiClient>(c => c.BaseAddress = new Uri("https://pricing.internal/"))
                .AddStandardResilienceHandler();
        return services;
    }
}
```

Use **named** or **typed** clients — never `new HttpClient()` directly. Typed clients carry the resilience handler with them across DI scopes.

## 3. Per-call options on the standard handler

Override defaults via `AddStandardResilienceHandler(options => { … })`:

```csharp
services.AddHttpClient("slow-upstream")
        .AddStandardResilienceHandler(o =>
        {
            o.Retry.MaxRetryAttempts          = 5;
            o.AttemptTimeout.Timeout           = TimeSpan.FromSeconds(60);
            o.TotalRequestTimeout.Timeout      = TimeSpan.FromMinutes(5);
            o.CircuitBreaker.SamplingDuration  = TimeSpan.FromSeconds(60);
        });
```

## 4. Custom resilience pipeline (when standard doesn't fit)

```csharp
services.AddHttpClient("clamav")
        .AddResilienceHandler("clamav-pipeline", builder => builder
            // RESILIENCE: total timeout MUST be outermost — caps entire pipeline
            .AddTimeout(TimeSpan.FromMinutes(2))
            .AddConcurrencyLimiter(permitLimit: 8, queueLimit: 4)
            .AddCircuitBreaker(new HttpCircuitBreakerStrategyOptions
            {
                FailureRatio = 0.20, SamplingDuration = TimeSpan.FromSeconds(60),
                MinimumThroughput = 10, BreakDuration = TimeSpan.FromSeconds(30),
            })
            .AddRetry(new HttpRetryStrategyOptions
            {
                MaxRetryAttempts = 3, BackoffType = DelayBackoffType.Exponential, UseJitter = true,
            })
            .AddTimeout(TimeSpan.FromSeconds(30)));   // per-attempt
```

## 5. Idempotency-aware retry rules

> **Rule:** Retry on POST/PATCH/DELETE only when the target endpoint contract supports an `Idempotency-Key`. The default `ShouldHandle` predicate in `Http.Resilience` excludes mutating verbs from retry — do not override this except for endpoints documented to accept idempotency keys.

Failure mode: retrying a non-idempotent POST after a transient 503 → duplicate side effects on the upstream (the dual-write footgun, HTTP edition).

```csharp
services.AddHttpClient("payments")
        .AddResilienceHandler("payments-pipeline", builder => builder
            .AddRetry(new HttpRetryStrategyOptions
            {
                MaxRetryAttempts = 3,
                ShouldHandle = args =>
                {
                    // RESILIENCE: POST retry permitted only when the request carries an Idempotency-Key
                    var isMutating = args.Outcome.Result?.RequestMessage?.Method is { } m
                                     && (m == HttpMethod.Post || m == HttpMethod.Patch || m == HttpMethod.Delete);
                    var hasIdem = args.Outcome.Result?.RequestMessage?.Headers.Contains("Idempotency-Key") == true;
                    if (isMutating && !hasIdem) return ValueTask.FromResult(false);
                    return HttpClientResiliencePredicates.IsTransient(args.Outcome);
                },
            }));
```

The idempotency-key contract on both ends lives in `backend-feature-patterns §8` (handler) and `fastendpoints-patterns §6` (endpoint).

## 6. DelegatingHandler chain order (joint rule with keycloak-patterns)

> **Rule:** Register the M2M `DelegatingHandler` BEFORE the resilience handler in the pipeline. Retries replay the request; replays must carry a fresh (or cached) token. If the resilience handler runs first, retried requests can fire with stale or missing auth headers.

Canonical order: `M2MTokenAttachHandler` → resilience handler → outbound socket.

```csharp
services.AddTransient<M2MTokenHandler>();
services.AddHttpClient<IPricingApiClient, PricingApiClient>(c => c.BaseAddress = new Uri("https://pricing.internal/"))
        // HANDLER-ORDER: M2M token attach FIRST — replays carry the cached token
        .AddHttpMessageHandler<M2MTokenHandler>()
        // RESILIENCE: resilience pipeline runs second — retries replay through the token handler
        .AddStandardResilienceHandler();
```

The `M2MTokenHandler` itself lives in `keycloak-patterns §8`.

## 7. Transient vs permanent errors

The default `HttpClientResiliencePredicates.IsTransient(...)` retries on:

| Condition | Retry? |
|---|---|
| HTTP 408, 429, 500, 502, 503, 504 | Yes |
| `HttpRequestException` | Yes |
| `TaskCanceledException` (no user cancellation) | Yes |
| 4xx other than the above | No |
| `OperationCanceledException` (user-cancelled) | No |
| `JsonException` (deserialization) | No |

Custom predicates **extend** the default; don't replace it. Domain-specific retryable codes (e.g. a 422 that means "queue full, retry later") chain on top.

## 8. Bulkhead / concurrency limiting

`AddConcurrencyLimiter` caps simultaneous in-flight requests to an upstream. Use for upstreams with strict server-side concurrency limits (e.g. ClamAV daemon with a small worker pool). Per-host concurrency: 10 default; per-endpoint can be lower. The limit is **per named `HttpClient`**, not per-process global.

## 9. Circuit breaker tuning

The standard handler uses a failure-rate breaker (10% over a sampling window) — appropriate for most upstreams. Tune when a chatty upstream causes flap: widen `SamplingDuration` (60s+), raise `MinimumThroughput`, or extend `BreakDuration`. **Never disable** the circuit breaker — tune, don't remove.

## 10. Timeouts (per-attempt vs total)

- **Per-attempt timeout** caps a single HTTP request.
- **Total request timeout** caps the entire pipeline including retries — it MUST be the outermost layer.

**Rule:** `total ≥ per-attempt × (max retries + 1) + sum of backoff intervals`. Otherwise the total is the binding constraint and retries get cancelled mid-flight, defeating the purpose.

## 11. Logging and OTel

`Microsoft.Extensions.Http.Resilience` auto-emits `ActivitySource` events for retries, breaks, and timeouts. Spans propagate via `Activity.Current`. Don't manually log retry attempts in user code — that duplicates the OTel events and pollutes logs. See `observability-backend` for the export configuration (Phase 5 placeholder).

## 12. Wolverine handler retry — the boundary

Wolverine handlers retry on `Handle` exceptions per `wolverine-patterns §9` policies (`[RetryNow]`, `[RetryLater]`). A handler that calls an HTTP client (with this skill's resilience) and exhausts HTTP retries throws — and Wolverine's retry policy then decides whether to redeliver the message.

**HTTP resilience handles in-the-moment transients; Wolverine retry handles across-time durability.** Both layers are needed.

## 13. Anti-patterns

- Raw `new HttpClient()` — no resilience, no instrumentation, no DI.
- Custom retry loops in app code — use the pipeline.
- Overriding `ShouldHandle` to retry POST without an idempotency contract — duplicate-side-effect risk.
- M2M `DelegatingHandler` registered AFTER the resilience handler — replays fire without auth.
- A `DelegatingHandler` that REMOVES auth headers (for any reason) — security audit failure.
- Disabling the circuit breaker — tune sampling and break duration instead.
- Per-attempt timeout > total request timeout — logical inversion; retries impossible.
- Manually logging retry attempts — duplicates OTel.
- Polly v7 `Policy.WrapAsync` / `PolicyWrap` syntax — legacy; use the v8 pipeline builder.
- Referencing the v7 wrapper package — use `Microsoft.Extensions.Http.Resilience`, not the v7 `Polly` HTTP package.

## 14. Testing

Simulate transients with a test `HttpMessageHandler` and assert on call count.

```csharp
[Fact]
public async Task Two_transient_failures_then_success_succeeds()
{
    var calls = 0;
    var handler = new StubHandler(req =>
    {
        calls++;
        return calls < 3
            ? new HttpResponseMessage(HttpStatusCode.ServiceUnavailable)
            : new HttpResponseMessage(HttpStatusCode.OK);
    });

    var services = new ServiceCollection();
    services.AddHttpClient("test").ConfigurePrimaryHttpMessageHandler(() => handler).AddStandardResilienceHandler();
    var sp = services.BuildServiceProvider();
    var http = sp.GetRequiredService<IHttpClientFactory>().CreateClient("test");

    var resp = await http.GetAsync("https://example/health");
    Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
    Assert.Equal(3, calls);
}
```

## 15. Comment markers emitted by this skill

- `// RESILIENCE:` — annotates a resilience-handler registration or critical pipeline option.
- `// HANDLER-ORDER:` — annotates the DelegatingHandler-vs-resilience order at the registration site.

The canonical comment-markers index lives in `backend-feature-patterns §10`.

## 16. References

- `keycloak-patterns §8` — `M2MTokenHandler` lives there; chain order is joint rule in §6.
- `wolverine-patterns §9` — handler-level retry; cross-cutting boundary in §12.
- `backend-feature-patterns §8` — idempotency-key handler contract.
- `fastendpoints-patterns §6` — idempotency-key endpoint contract.
- `elasticsearch-patterns §10, §11` — ES client uses this resilience stack.
- `file-pipeline-patterns §5` — `IVirusScanService` (nClam) uses this resilience stack.
- `observability-backend` — OTel auto-instrumentation (Phase 5 placeholder).
- `.specify/memory/system-context.md` — project-specific upstream SLAs / timeout defaults.
