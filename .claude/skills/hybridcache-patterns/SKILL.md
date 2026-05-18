---
name: hybridcache-patterns
description: |
  HybridCache as primary cache API for .NET 10 with L1 in-process + L2 Redis Sentinel. Covers GetOrCreateAsync, tag-based invalidation, cross-instance invalidation via Wolverine integration events, TTL conventions, key naming, and escape hatches for distributed locks (RedLock.net), rate limiting, and Redis Streams. Use whenever a feature reads or invalidates cached data.
when_to_load:
  - Task mentions: cache, caching, invalidate, ttl, hybrid cache, distributed lock, rate limit, redis
  - Files touched: any *Repository.cs / *QueryHandler.cs with read paths, any handler that mutates state and should invalidate
co_loads_with:
  - wolverine-patterns (cross-instance invalidation events)
  - persistence-patterns (cache-aside around Dapper reads)
---

# HybridCache Patterns

## 1. Mental model

```
Application code → HybridCache.GetOrCreateAsync (primary path)
                  │
                  ├── L1 in-process (microseconds, per-instance)
                  └── L2 Redis Sentinel (millis, shared across instances)

Tag-based invalidation: HybridCache.RemoveByTagAsync(tag)
Cache-coherent invalidation across instances: Wolverine integration event
  → handler on each instance calls HybridCache.RemoveAsync / RemoveByTagAsync

Escape hatches (NOT via HybridCache):
  - Distributed locks → RedLock.net
  - Rate limiting → Redis sorted-set sliding window (or AspNetCore.RateLimiting)
  - Redis Streams → only when ordered partitioned consumption is required
```

**Why HybridCache, not raw `StackExchange.Redis`:** stampede protection (a single concurrent factory call per key), source-generated serializers, two-tier L1+L2 semantics, and tag-based bulk invalidation — all built in. Raw `IDatabase` access is reserved for the three escape hatches; everything else routes through `HybridCache`.

## 2. Key naming convention

Format: `<context>:<aggregate>:<id>[:<projection>]` — lowercase, colon-separated, no spaces.

| Pattern | Example |
|---|---|
| Entity by id | `yourcontext:listing:123` |
| Projection | `yourcontext:listing:123:summary` |
| Paged query | `yourcontext:search:active:page:1` |
| User session | `yourcontext:session:<sessionId>` |

**Tag naming**: `<context>:<aggregate>` (e.g. `yourcontext:listing`) — tags are the bulk-invalidation handle. Every cache entry that backs a queryable aggregate must carry the aggregate tag.

## 3. TTL conventions

| Data shape | TTL (L2 / `Expiration`) | L1 (`LocalCacheExpiration`) |
|---|---|---|
| Hot read (per-request reuse) | 30s | 30s |
| Reference data (rarely changes) | 1h | 5m |
| User session data | 15m | 1m |
| Search results page | 60s | 30s |
| Single aggregate by ID | 5m | 1m |

**Rule:** `LocalCacheExpiration` ≤ `Expiration`. Never invert — L1 outliving L2 produces phantom hits after L2 eviction. TTL > 1 hour requires a documented bulk-invalidation strategy (anti-pattern §8).

## 4. GetOrCreateAsync — the canonical read pattern

```csharp
namespace YourContext.Application.Listings.GetDetail;

public sealed class GetListingDetailQueryHandler(HybridCache cache, IListingReadRepository reads)
{
    private static readonly HybridCacheEntryOptions Options = new()
    {
        Expiration            = TimeSpan.FromMinutes(5),
        LocalCacheExpiration  = TimeSpan.FromMinutes(1),
    };

    public async Task<ErrorOr<ListingDetailDto>> Handle(GetListingDetailQuery q, CancellationToken ct)
    {
        // CACHE-TAG: yourcontext:listing — bulk-invalidated on any listing write
        var dto = await cache.GetOrCreateAsync(
            $"yourcontext:listing:{q.ListingId}:detail",
            async token => await reads.GetDetailAsync(q.ListingId, token),
            Options,
            tags: ["yourcontext:listing"],
            cancellationToken: ct);

        return dto is null ? Error.NotFound("Listing.NotFound") : dto;
    }
}
```

The factory delegate carries the cancellation token. If the factory throws, the exception propagates and nothing is cached — that is intentional.

## 5. Invalidation — same-instance

```csharp
// Single key
await cache.RemoveAsync($"yourcontext:listing:{id}:detail", ct);     // CACHE-INVALIDATE

// Bulk by tag (clears every entry carrying the tag on THIS instance only)
await cache.RemoveByTagAsync("yourcontext:listing", ct);             // CACHE-INVALIDATE
```

Call sites: in a command handler, invalidate **after** `db.SaveChangesAsync(ct)` and inside the same `[Transactional]` boundary — invalidation must not run if the transaction rolls back. For cross-instance coherence, see §6.

## 6. Invalidation — cross-instance (critical rule)

> **Rule:** `HybridCache` L1 lives per process. Removing a key on instance A does **not** clear instance B's L1 — instance B keeps serving stale until its L1 TTL expires. To invalidate L1 across the fleet, publish a Wolverine integration event after the state mutation and subscribe to it on every instance.

The publish uses the outbox pattern (see `wolverine-patterns` §4 — outbox guarantees the event commits with the DB write). The subscriber side belongs to this skill:

```csharp
namespace YourContext.Contracts.Listings;
public sealed record ListingUpdatedIntegrationEvent(Guid ListingId);

namespace YourContext.Application.Listings.CacheInvalidation;
public sealed class OnListingUpdatedInvalidateCache(HybridCache cache)
{
    public Task Handle(ListingUpdatedIntegrationEvent evt, CancellationToken ct)
        // CACHE-INVALIDATE: clears every cached projection of this listing on this instance
        => cache.RemoveByTagAsync("yourcontext:listing", ct).AsTask();
}
```

Every app instance hosts this handler. Wolverine fans the brokered event to all subscribers; each instance clears its own L1 and the shared L2 entry. TTL is the safety net if a broker outage drops a notification.

## 7. Cache-aside in query handlers

The handler injects `HybridCache` and the read-side abstraction (Dapper-backed). The cache layer is explicit — no decorator magic — so the call site reads top-to-bottom and the factory delegate is the single read.

```csharp
public sealed class SearchListingsQueryHandler(HybridCache cache, IListingSearchReader reader)
{
    public async Task<ErrorOr<IReadOnlyList<ListingCardDto>>> Handle(SearchListingsQuery q, CancellationToken ct)
    {
        var key = $"yourcontext:search:{q.Region}:page:{q.Page}";
        // CACHE-TAG: tag enables bulk invalidation when any listing in the region changes
        var page = await cache.GetOrCreateAsync(
            key,
            token => reader.SearchAsync(q.Region, q.Page, token).AsTask(),
            new() { Expiration = TimeSpan.FromSeconds(60), LocalCacheExpiration = TimeSpan.FromSeconds(30) },
            tags: ["yourcontext:listing"],
            cancellationToken: ct);

        return page.ToList();
    }
}
```

Search reads from Elasticsearch are not entity-keyed; they get a short TTL and the aggregate tag so any write invalidates them in bulk.

## 8. Anti-patterns

- Caching write-side commands. Cache read-side queries only.
- Storing EF Core aggregate entities in cache. Cache projections / DTOs.
- Tagless entries on data that needs bulk invalidation.
- Calling `IDatabase` or `ConnectionMultiplexer` directly in application code (only inside an escape-hatch adapter — see §10).
- TTL > 1 hour without a documented bulk-invalidation strategy.
- Caching paged search results without a coherent invalidation tag scheme.
- `LocalCacheExpiration > Expiration` (must be ≤).
- Invalidating from inside the EF transaction. Invalidate after commit, or via the integration-event handler in §6.

## 9. Escape hatch: distributed locks (RedLock.net)

For exactly-once cross-instance operations that a Wolverine saga cannot model (rare). Not for command deduplication (Wolverine inbox handles that) or event debouncing (saga timeout handles that).

```csharp
public sealed class NightlyReportRunner(RedLockFactory redlock, IReportService reports)
{
    public async Task RunAsync(DateOnly day, CancellationToken ct)
    {
        await using var heldLock = await redlock.CreateLockAsync(
            resource: $"yourcontext:lock:nightly-report:{day:yyyyMMdd}",
            expiryTime: TimeSpan.FromMinutes(10),
            waitTime:   TimeSpan.FromSeconds(2),
            retryTime:  TimeSpan.FromMilliseconds(200),
            cancellationToken: ct);

        if (!heldLock.IsAcquired) return;          // another instance is running it
        await reports.GenerateAsync(day, ct);
    }
}
```

Lock expiry must exceed expected operation duration. Always pass `expiryTime` — never infinite locks.

## 10. Escape hatch: rate limiting

Two options. Pick (a) when per-instance is acceptable; pick (b) when the limit must be shared across instances.

**(a) `Microsoft.AspNetCore.RateLimiting`** — preferred default, no Redis dependency.

**(b) Redis sorted-set sliding window** — when shared counters are required. The raw `IDatabase` access here is the **only** place in application code that touches it, and only inside an adapter behind `IRateLimiter` (port-and-adapter convention).

```csharp
public sealed class RedisSlidingWindowRateLimiter(IConnectionMultiplexer redis) : IRateLimiter
{
    private const string Script = """
        redis.call('ZREMRANGEBYSCORE', KEYS[1], 0, ARGV[1] - ARGV[2])
        redis.call('ZADD', KEYS[1], ARGV[1], ARGV[3])
        redis.call('PEXPIRE', KEYS[1], ARGV[2] * 2)
        return redis.call('ZCARD', KEYS[1])
        """;

    public async Task<bool> TryAcquireAsync(string bucket, int limit, TimeSpan window, CancellationToken ct)
    {
        // CONFIGUREAWAIT: adapter (library-style) code retains ConfigureAwait(false).
        var db = redis.GetDatabase();
        var now = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
        var count = (long)await db.ScriptEvaluateAsync(
            Script,
            new RedisKey[] { $"yourcontext:rate:{bucket}" },
            new RedisValue[] { now, (long)window.TotalMilliseconds, Guid.NewGuid().ToString("N") })
            .ConfigureAwait(false);
        return count <= limit;
    }
}
```

## 11. Escape hatch: Redis Streams

Use only when ordered, partitioned consumption is required and Wolverine's transports cannot model the partitioning. This is almost never the right answer — validate the design with `wolverine-patterns` §6 (integration events) and §7 (sagas) before reaching for Streams. No code example: if you need one, the design needs review first.

## 12. Testing

`HybridCache` ships with a real in-memory composition suitable for handler tests — prefer it over hand-rolled doubles so stampede protection and tag semantics are covered.

```csharp
[Fact]
public async Task GetDetail_caches_and_invalidates_by_tag()
{
    var services = new ServiceCollection().AddHybridCache().Services.BuildServiceProvider();
    var cache = services.GetRequiredService<HybridCache>();
    var reads = Substitute.For<IListingReadRepository>();
    reads.GetDetailAsync(Arg.Any<Guid>(), Arg.Any<CancellationToken>())
         .Returns(new ListingDetailDto(Guid.NewGuid(), "title"));

    var handler = new GetListingDetailQueryHandler(cache, reads);
    var id = Guid.NewGuid();

    _ = await handler.Handle(new GetListingDetailQuery(id), default);
    _ = await handler.Handle(new GetListingDetailQuery(id), default);
    await reads.Received(1).GetDetailAsync(id, Arg.Any<CancellationToken>());   // hit on second call

    await cache.RemoveByTagAsync("yourcontext:listing");                        // CACHE-INVALIDATE
    _ = await handler.Handle(new GetListingDetailQuery(id), default);
    await reads.Received(2).GetDetailAsync(id, Arg.Any<CancellationToken>());   // miss after tag clear
}
```

## 13. Comment markers emitted by this skill

- `// CACHE-TAG:` — annotates the tag(s) a cache entry is filed under.
- `// CACHE-INVALIDATE:` — annotates an invalidation call (`RemoveAsync` / `RemoveByTagAsync`).
- `// CONFIGUREAWAIT:` — adapter/library code retains `ConfigureAwait(false)`; handlers do not (Wolverine controls context).

## 14. References

- `wolverine-patterns` §6 — integration events for cross-instance invalidation; §4 — outbox guarantees event commits with the DB write.
- `persistence-patterns` — the Dapper read sits inside the `GetOrCreateAsync` factory delegate.
