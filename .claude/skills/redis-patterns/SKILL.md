---
name: redis-patterns
description: "Load when: designing or implementing caching, session stores, rate limiting, or distributed locks using Redis. Primary/replica/sentinel topology, key naming, TTL strategy, cache-aside, eviction. Loaded by: sk.datamodel, sk.architecture, sk.implement (backend)."
---

# Redis Patterns (Primary / Replica / Sentinel)

## Purpose
Production patterns for Redis in a primary + replica + 3-sentinel topology. Covers `StackExchange.Redis` configuration, key naming conventions, TTL strategy, data structure selection, cache-aside pattern, eviction policy, and distributed locking. Redis is used for: session cache, token claim cache, rate limiting counters, hot-data cache, and distributed locks.

## Core Rules

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

### Cache-aside implementation
```csharp
public async Task<ListingDetailDto?> GetListingAsync(Guid publicId, CancellationToken ct)
{
    var key = $"listing-svc:listing:{publicId}:detail";
    var db  = _redis.GetDatabase();

    var cached = await db.StringGetAsync(key);
    if (cached.HasValue)
        return JsonSerializer.Deserialize<ListingDetailDto>(cached!);

    var listing = await _repo.GetByPublicIdAsync(publicId, ct);
    if (listing is null) return null;

    var dto = listing.ToDetailDto();
    await db.StringSetAsync(key, JsonSerializer.Serialize(dto), TimeSpan.FromMinutes(5));
    return dto;
}

// On update — invalidate, never update
public async Task InvalidateListingCacheAsync(Guid publicId)
    => await _redis.GetDatabase().KeyDeleteAsync($"listing-svc:listing:{publicId}:detail");
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
* `sk.datamodel` for any unit whose data model includes a Redis access pattern

## When NOT to Use
* Durable message queuing → RabbitMQ + MassTransit
* Workflow state → Elsa v3 + PostgreSQL
* Long-term persistent storage → PostgreSQL
* Full-text or geo search → Elasticsearch
