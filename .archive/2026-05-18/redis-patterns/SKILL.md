---
name: redis-patterns
description: "Load when: designing or implementing caching, session stores, rate limiting, or distributed locks using Redis. Primary/replica/sentinel topology, key naming, TTL strategy, cache-aside, eviction."
---

# Redis Patterns (Primary / Replica / Sentinel)

## Purpose
Production patterns for Redis in a primary + replica + 3-sentinel topology. Covers `StackExchange.Redis` configuration, key naming conventions, TTL strategy, data structure selection, cache-aside pattern, eviction policy, and distributed locking. Redis is used for: session cache, token claim cache, rate limiting counters, hot-data cache, and distributed locks.

## Core Rules

### Role in CQRS — Read-Side Only (with two exceptions)

Redis participates in the architecture in three roles. Two of them are read-side only; one is infrastructure-shared.

| Role | Side | Where it lives |
|---|---|---|
| **Entity / DTO cache** (cache-aside) | Read side only | Inside an `IQueryHandler<...>` or as a `Cached{Entity}ReadRepository` decorator over `I{Entity}ReadRepository` (Infrastructure layer) |
| **Rate limiting counters** | Cross-cutting | BFF or service middleware — not visible to handlers |
| **Distributed locks** | Cross-cutting | Infrastructure utilities — used wherever exclusive coordination is needed |

**Hard rules for the cache role:**
* A command handler **never** reads from Redis. Commands always load aggregates fresh through `I{Aggregate}WriteRepository` (EF Core) — caching a domain aggregate would invite stale-write bugs.
* A command handler **never** writes a DTO into Redis. The cache is populated lazily on the next read after a write invalidates it.
* Cache invalidation on write happens by publishing a domain event (in-process `INotification` or integration event) that an invalidation handler consumes — the command handler does not call Redis directly.
* Cache values are **read-model DTOs**, never aggregate roots, never EF Core entity graphs.

### Consistency Model — Eventual Between Cache and Source of Truth

The cache and the database are **not** kept in lockstep. Treat the cache as an eventually consistent read-side projection of the source of truth (PostgreSQL).

* **Stale-read window after a write**: bounded by *(invalidation event publish + handler latency)*. Typically sub-second in steady state; can grow to seconds under load. This is acceptable by design — document it in the unit's knowledge base for any access pattern that uses cache-aside.
* **Read-your-own-writes is NOT guaranteed via the cache**. After a command handler commits a write, the same caller's next read may still hit a stale cached value (the invalidation `INotification` runs after `CommitAsync` but races with concurrent reads). If an endpoint must reflect the user's own write immediately, the read repository must bypass the cache for that request — typically by reading directly from the underlying `inner` repository, or by routing the read to the primary database connection (not a replica).
* **No replica reads inside the same request as a write**: if a request both writes (command) and reads (query) the same aggregate, the query must target the primary database — never a replica. Replica lag is a separate eventual-consistency surface from cache lag, and stacking the two yields user-visible regressions.
* **Cache invalidation is best-effort**, not transactional. The `INotification` invalidation handler runs in-process after `CommitAsync` succeeds; if the process crashes between commit and invalidation, the cached value is stale until its TTL expires. **TTL is the safety net** — every key MUST have a TTL (see TTL Strategy) so any missed invalidation is bounded in blast radius. For data where stale reads are unacceptable, do not cache it.
* **No write-through, no write-behind**: we use cache-aside only. Writes go to PostgreSQL; the cache is invalidated (deleted), never updated. The next read repopulates lazily. This avoids the dual-write consistency problems write-through introduces and matches the CQRS read/write split.
* **Cross-service cache coherence**: when service A's data is cached inside service B (e.g., a denormalised read model), invalidation flows through MassTransit integration events, not direct Redis calls across services. Service B's MassTransit consumer subscribes to the integration event and invalidates its own local cache key.

### Topology & Connection
* Topology: 1 primary (writes), 1+ replicas (reads), 3 sentinels (HA failover). Never connect directly to primary IP — always connect via sentinel.
* `StackExchange.Redis` sentinel configuration:
  ```csharp
  ConfigurationOptions.Parse("sentinel://sentinel-a:26379,sentinel-b:26379,sentinel-c:26379/mymaster")
  ```
* Register as singleton: `IConnectionMultiplexer` is thread-safe and expensive to create.
* Use `connectionMultiplexer.GetDatabase()` per operation — lightweight, not pooled separately.
* Read from replica for non-critical reads: `GetDatabase(asyncState: ReplicaPreference.PreferReplica)` — do not read from replica for read-your-own-writes scenarios (e.g., after a cache write in the same request).
* Circuit breaker: wrap Redis calls with Polly retry (3 attempts, 100ms intervals). On circuit open, fall through to the source of truth — Redis unavailability must not crash the service.
* Never block the ASP.NET Core thread pool: always use `*Async` Redis methods.

### Key Naming Convention
Format: `{service}:{entity}:{id}:{variant}`

| Pattern | Example |
|---|---|
| Single entity cache | `listing-svc:listing:a3f2c1:detail` |
| User session | `auth-svc:session:{session_id}` |
| Auth token claim cache | `auth-svc:token-claims:{token_hash}` |
| Rate limit counter | `bff:rate-limit:{user_id}:{window}` |
| Distributed lock | `{service}:lock:{resource}:{resource_id}` |
| Search result cache | `listing-svc:search:{query_hash}:{page}` |

* Always prefix with service name — prevents cross-service key collisions on a shared cluster.
* Use `:` as separator. No spaces. Lowercase. Alphanumeric IDs only in key paths.
* Hash query parameters (SHA256 hex, truncated to 12 chars) rather than embedding raw query strings.

### TTL Strategy — Every Key Must Have a TTL
| Use case | TTL |
|---|---|
| Auth token claim cache | Remaining token lifetime (not fixed) |
| User session (Infinispan delegates to Redis) | 30 min sliding |
| Listing detail cache | 5 min |
| Search result cache | 2 min |
| Rate limit counter | Window size (1 min, 15 min, etc.) |
| Distributed lock | Operation timeout + 30s buffer |
| Hot config/feature flags | 60 sec |

* Never create a key without `expiry` — orphaned keys cause unbounded memory growth.
* Use `EXPIREAT` (absolute) for token-lifetime TTLs. Use `EXPIRE` (relative) for sliding windows.
* Sliding TTL for sessions: update expiry on every access with `KeyExpireAsync`.

### Data Structures
* **String**: single serialized object (JSON). Use for entity caches, token caches. Keep values < 100KB.
* **Hash**: field-per-attribute for objects you partially update (`HSET`, `HGET`). Use when writing individual fields is frequent.
* **Sorted Set**: leaderboards, time-ordered queues, rate limit sliding windows (score = timestamp). `ZADD`, `ZRANGEBYSCORE`.
* **List**: simple FIFO queues when ordering matters and loss is acceptable. Not for durable messaging (use RabbitMQ).
* **Set**: membership checks, tag-based lookups. `SISMEMBER`, `SMEMBERS`.
* **Bitmap / HyperLogLog**: cardinality estimation (unique visitors), bloom filter approximations.
* Default to **String** with JSON serialisation. Switch to Hash only when partial field updates are a real access pattern.

### Cache-Aside Pattern
```
Read: check cache → hit: return. miss: read DB → write cache → return.
Write: write DB → invalidate cache (delete key). Do NOT update cache on write.
```
* On cache write after DB read: set TTL appropriate for the data freshness requirement.
* On cache miss under high concurrency: use distributed lock to prevent cache stampede for expensive computations.
* Never write to cache inside a database transaction — write after `CommitAsync()`.
* Invalidation on write: delete the key, do not update it. Avoids stale-write race conditions.

### Eviction Policy
* Configure `maxmemory-policy allkeys-lru` — evict least recently used keys when memory is full.
* Do NOT use `noeviction` — Redis will error on writes when full, cascading to service failures.
* Monitor `evicted_keys` metric. Sustained eviction means the cache is undersized — scale up memory or reduce TTLs.
* Separate Redis instances (or logical DBs 0–15) for: session cache (DB 0), hot data cache (DB 1), rate limiting (DB 2). Never mix concerns in the same keyspace.

### Distributed Locks (Redlock via StackExchange.Redis)
* Use `StackExchange.Redis.Extensions.Core` Redlock or `RedLock.net` for distributed locking.
* Lock TTL = expected operation duration × 3. Always set a safety TTL — never infinite locks.
* Always release in a `finally` block. Use `DeleteAsync` with a Lua script to compare-and-delete (prevent releasing another holder's lock):
  ```lua
  if redis.call("get", KEYS[1]) == ARGV[1] then return redis.call("del", KEYS[1]) else return 0 end
  ```
* Do NOT use Redis locks for anything requiring strong consistency guarantees — they are advisory, not strict.

### Serialisation
* Use `System.Text.Json` with `JsonSerializerOptions` set to camelCase, ignore null.
* Keep cached objects lean — do not cache full EF Core entity graphs. Cache read-model projections.
* Version your cached objects: include a `v` field or key suffix. On schema change, increment version to avoid deserialising stale shapes.

### Observability
* Metrics to expose: `redis_hit_total{service,key_pattern}`, `redis_miss_total{service,key_pattern}`, `redis_error_total{service,operation}`, `redis_operation_duration_seconds{service,operation}`.
* Log at WARN when falling back to DB due to Redis error. Include key pattern (never the full key with IDs).
* Alert: `redis_error_total` rate > 5/min per service.

## Patterns / Examples

### Singleton registration
```csharp
services.AddSingleton<IConnectionMultiplexer>(_ =>
{
    var config = ConfigurationOptions.Parse(
        "sentinel://sentinel-a:26379,sentinel-b:26379,sentinel-c:26379/mymaster");
    config.AbortOnConnectFail = false;
    config.ConnectRetry = 3;
    config.ReconnectRetryPolicy = new ExponentialRetry(TimeSpan.FromSeconds(1));
    return ConnectionMultiplexer.Connect(config);
});
```

### Cache-aside as a read-side decorator (preferred)

The query handler is unaware of caching — it depends on `IListingReadRepository` only. The cache lives in a decorator registered ahead of the concrete read repository. This keeps the Application layer agnostic of infrastructure choices.

```csharp
// Application layer — query handler depends on the read repository abstraction only
public class GetListingDetailHandler(IListingReadRepository reads)
    : IQueryHandler<GetListingDetailQuery, ListingDetailDto>
{
    public async Task<Result<ListingDetailDto>> Handle(GetListingDetailQuery q, CancellationToken ct)
    {
        var dto = await reads.GetDetailAsync(q.ListingId, ct);
        return dto is null
            ? Result.Failure<ListingDetailDto>(new NotFoundError("Listing not found"))
            : Result.Success(dto);
    }
}

// Infrastructure layer — cache-aside decorator over the Dapper-backed read repository
public class CachedListingReadRepository(
    IListingReadRepository inner,                  // the Dapper-backed concrete impl
    IConnectionMultiplexer redis,
    ILogger<CachedListingReadRepository> logger)
    : IListingReadRepository
{
    public async Task<ListingDetailDto?> GetDetailAsync(Guid id, CancellationToken ct)
    {
        var key = $"listing-svc:listing:{id}:detail";
        var db  = redis.GetDatabase();

        try
        {
            var cached = await db.StringGetAsync(key);
            if (cached.HasValue)
                return JsonSerializer.Deserialize<ListingDetailDto>(cached!);
        }
        catch (RedisException ex)
        {
            // Redis unavailable — fall through to source of truth, never crash the request
            logger.LogWarning(ex, "Cache read failed for {Key}; falling through to source", key);
        }

        var dto = await inner.GetDetailAsync(id, ct);
        if (dto is null) return null;

        try
        {
            await db.StringSetAsync(key, JsonSerializer.Serialize(dto), TimeSpan.FromMinutes(5));
        }
        catch (RedisException ex)
        {
            logger.LogWarning(ex, "Cache write failed for {Key}; serving uncached", key);
        }
        return dto;
    }
}

// DI registration — decorator wraps the concrete impl
services.AddScoped<IListingReadRepository, DapperListingReadRepository>();
services.Decorate<IListingReadRepository, CachedListingReadRepository>(); // Scrutor
```

**Scope of this decorator pattern:** the Redis cache decorator wraps `I{Entity}ReadRepository` (entity-shaped reads backed by Dapper/PostgreSQL) only. It is **never** wrapped around `I{Entity}SearchRepository` (Elasticsearch-backed search reads — see `elasticsearch-patterns` and `csharp-clean-arch` Read side). Search results are query-hashed, not entity-keyed; if a search index needs result caching, do it inside the search repo impl with a short TTL on the query-hash key, not via this decorator.

### Cache invalidation — driven by domain events, never by command handlers

The command handler does not call Redis directly. It mutates the aggregate; the resulting domain event triggers an in-process notification handler that invalidates the affected keys. This keeps the write side ignorant of the cache and prevents dual-write bugs.

```csharp
// Application layer — invalidation handler subscribes to the domain event
public class InvalidateListingCacheOnUpdated(IConnectionMultiplexer redis)
    : INotificationHandler<ListingUpdatedNotification>
{
    public Task Handle(ListingUpdatedNotification n, CancellationToken ct)
        => redis.GetDatabase().KeyDeleteAsync($"listing-svc:listing:{n.ListingId}:detail");
}
```

### Rate limit counter (sliding window)
```csharp
public async Task<bool> IsAllowedAsync(string userId, int limitPerMinute)
{
    var db  = _redis.GetDatabase();
    var key = $"bff:rate-limit:{userId}:1m";
    var now = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();

    var tx = db.CreateTransaction();
    _ = tx.SortedSetRemoveRangeByScoreAsync(key, 0, now - 60_000); // remove old entries
    _ = tx.SortedSetAddAsync(key, Guid.NewGuid().ToString(), now);
    _ = tx.KeyExpireAsync(key, TimeSpan.FromMinutes(2));
    await tx.ExecuteAsync();

    var count = await db.SortedSetLengthAsync(key);
    return count <= limitPerMinute;
}
```

## When to Use
* Designing caching strategy for any service
* Implementing token or session caches
* Rate limiting at BFF or service level
* Distributed locks for critical sections (e.g., preventing duplicate job execution)
* Any unit whose data model includes a Redis access pattern (cache, session, rate-limit, lock)

## When NOT to Use
* Durable message queuing → RabbitMQ + MassTransit
* Workflow state → Elsa v3 + PostgreSQL
* Long-term persistent storage → PostgreSQL
* Full-text or geo search → Elasticsearch
