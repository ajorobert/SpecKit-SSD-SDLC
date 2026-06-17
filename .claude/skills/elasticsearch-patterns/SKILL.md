---
name: elasticsearch-patterns
description: |
  Elasticsearch 8.x for .NET 10 search with Elastic.Clients.Elasticsearch. Covers index modeling, mapping, geo search (polygon, radius, bounding-box, sort-by-distance), tenant-isolated queries, Wolverine event-driven indexing from PostgreSQL/PostGIS source of truth, alias-based zero-downtime reindex, HybridCache for stable search results. Use whenever a feature reads or writes the search index.
when_to_load:
  - Task mentions: search, elasticsearch, full-text, geo, polygon, radius, bounding-box, near, distance, index, mapping, reindex, alias, ISearchService
  - Files touched: any *SearchService.cs, *IndexHandler.cs, *Mapping.cs in a search-related folder
co_loads_with:
  - wolverine-patterns (index handler is an event handler)
  - persistence-patterns (PostGIS source of truth)
  - backend-feature-patterns (query handler injects ISearchService)
references:
  - hybridcache-patterns (cache stable search results)
  - keycloak-patterns (IUserContext.TenantId enforced on every query)
---

# Elasticsearch Patterns

## 1. Mental model

```
Source of truth (write side)        Search side (denormalized)
   PostgreSQL + PostGIS                Elasticsearch index
        │                                    ▲
        │ aggregate state mutation           │ index update
        │ domain event published             │
        │ (outbox, atomic)                   │
        ▼                                    │
   Wolverine outbox  ─── integration event ──┘
                            │
                            ▼
              SearchIndexHandler<T>
                  uses _es.IndexAsync(...)
                  to insert/update the denormalized doc

Query path:
   Endpoint → query handler → ISearchService<T> → Elasticsearch query
                                                       │
                                                       │ filter: tenant_id
                                                       │ + business filters
                                                       │ + geo (polygon/radius)
                                                       ▼
                                                  PagedResult<TDto>
```

Elasticsearch is a **projection**, not a source. The truth lives in PostgreSQL — if the index is wrong, rebuild it from the source. Indexing happens only inside Wolverine event handlers; nothing else writes to ES.

**When NOT to use Elasticsearch:** small datasets (use Dapper + PostGIS), exact-match lookups (use Postgres + index), strict ACID joins (not ES's job), audit logs (use partitioned PostgreSQL).

## 2. Index modeling

- One **index alias** per searchable aggregate (e.g. `listings`). Application code always queries the alias.
- Physical index name: `<alias>_<yyyyMMddHHmm>` (e.g. `listings_202605181430`). Reindex creates a new physical index and swaps the alias atomically.
- The document is a flattened **denormalized DTO**. Foreign-key relationships are flattened into the document — never joined at query time.
- Every document carries `tenant_id` (`keyword`) — non-negotiable.

```csharp
namespace YourContext.Infrastructure.Search.Documents;

public sealed record ListingSearchDocument
{
    public Guid Id { get; init; }                    // keyword (also _id)
    public Guid TenantId { get; init; }              // keyword — tenant filter
    public string Title { get; init; } = "";         // text + keyword sub-field
    public string Description { get; init; } = "";   // text
    public string Status { get; init; } = "";        // keyword
    public string Category { get; init; } = "";      // keyword (facet)
    public decimal Price { get; init; }              // double
    public string Currency { get; init; } = "";      // keyword
    public GeoLocation? Location { get; init; }      // geo_point
    public string Region { get; init; } = "";        // keyword
    public DateTimeOffset CreatedAt { get; init; }   // date
    public DateTimeOffset? ActivatedAt { get; init; }// date
}
```

## 3. Mapping conventions

| Use | Type | Notes |
|---|---|---|
| IDs, tenant_id, status, category | `keyword` | Exact match, facet, filter |
| Full-text searchable | `text` | Pair with `.keyword` sub-field for sort/exact |
| Date | `date` | ISO 8601 with explicit format |
| Single lat/lng | `geo_point` | Radius, distance-sort, bbox |
| Polygons / regions | `geo_shape` | Polygon-intersects queries |
| Numeric facet | `integer`/`long`/`double` | Match source type; no implicit conversion |

Declare mappings explicitly via the typed descriptor — **never rely on dynamic mapping in production**.

```csharp
var resp = await es.Indices.CreateAsync(physicalIndex, c => c
    .Mappings(m => m.Properties<ListingSearchDocument>(p => p
        .Keyword(k => k.Id)
        .Keyword(k => k.TenantId)
        .Text(t => t.Title, tt => tt.Fields(f => f.Keyword("keyword")))
        .Text(t => t.Description)
        .Keyword(k => k.Status).Keyword(k => k.Category).Keyword(k => k.Region).Keyword(k => k.Currency)
        .DoubleNumber(d => d.Price)
        .GeoPoint(g => g.Location)
        .Date(d => d.CreatedAt).Date(d => d.ActivatedAt)))
    .Settings(s => s.NumberOfShards(2).NumberOfReplicas(1)), ct);
if (!resp.IsValidResponse) return Error.Failure("Search.IndexCreateFailed", resp.DebugInformation);
```

## 4. Index handler — event-driven indexing (main write path)

Wolverine handlers subscribe to integration events emitted from the write side (see `wolverine-patterns` §6 for the publisher contract). The handler reads the projection from PostgreSQL via the source-of-truth read service (see `persistence-patterns` §4) — **never** reads from Elasticsearch to update Elasticsearch. The handler is idempotent: re-handling the same event re-indexes the same document state.

```csharp
namespace YourContext.Application.Search.Indexing;

public sealed class ListingIndexHandler(
    ElasticsearchClient es,
    IListingsReadService reads,
    IMapper mapper,
    ILogger<ListingIndexHandler> logger)
{
    public async Task<ErrorOr<Success>> Handle(ListingActivatedIntegrationEvent evt, CancellationToken ct)
    {
        var projection = await reads.GetSearchProjectionAsync(evt.ListingId, ct);
        if (projection is null)
        {
            // Source row was deleted between event publish and handler execution — propagate delete.
            // INDEX: delete by document id
            var del = await es.DeleteAsync<ListingSearchDocument>(evt.ListingId, d => d.Index("listings"), ct);
            return del.IsValidResponse || del.Result == Result.NotFound
                ? Result.Success
                : Error.Failure("Search.DeleteFailed", del.DebugInformation);
        }

        var doc = mapper.Map<ListingSearchDocument>(projection);
        // INDEX: upsert document by aggregate id; idempotent — re-handling re-applies the same state
        var resp = await es.IndexAsync(doc, i => i.Index("listings").Id(doc.Id), ct);
        if (!resp.IsValidResponse)
        {
            logger.LogError("Index write failed for {ListingId}: {Reason}", doc.Id, resp.DebugInformation);
            return Error.Failure("Search.IndexFailed", resp.DebugInformation);
        }
        return Result.Success;
    }
}

```

A `ListingDeletedIntegrationEvent` handler mirrors the delete branch above with `es.DeleteAsync<ListingSearchDocument>`.

## 5. Query handler shape — main read path

The Application layer depends on `ISearchService<TDto>`; the Elasticsearch-backed implementation lives in Infrastructure. The query handler (a Wolverine handler — see `backend-feature-patterns` §4) injects the service and returns DTOs mapped via Mapster (`backend-feature-patterns` §7).

> **Rule:** every search query MUST filter on `tenant_id` derived from `IUserContext.TenantId` (see `keycloak-patterns` §2). Enforcement lives in the search-service implementation — the query handler is **not** trusted to add the filter. A query without `tenant_id` filter is a tenant-isolation breach.

```csharp
namespace YourContext.Application.Search;

public interface IListingSearchService
{
    Task<ErrorOr<PagedResult<ListingCardDto>>> SearchAsync(ListingSearchQuery query, CancellationToken ct);
}

namespace YourContext.Infrastructure.Search;

public sealed class ListingSearchService(ElasticsearchClient es, IUserContext user, IMapper mapper)
    : IListingSearchService
{
    public async Task<ErrorOr<PagedResult<ListingCardDto>>> SearchAsync(ListingSearchQuery q, CancellationToken ct)
    {
        if (user.TenantId == Guid.Empty) return Error.Forbidden("Search.NoTenant", "Tenant context required");

        var resp = await es.SearchAsync<ListingSearchDocument>(s => s
            .Index("listings")
            .From((q.Page - 1) * q.PageSize)
            .Size(Math.Min(q.PageSize, 100))
            .Query(qq => qq.Bool(b => b
                .Must(m => string.IsNullOrWhiteSpace(q.Text)
                    ? m.MatchAll()
                    : m.Match(t => t.Field(f => f.Title).Query(q.Text!)))
                .Filter(
                    f => f.Term(t => t.Field(d => d.TenantId).Value(user.TenantId.ToString())),   // tenant_id — non-negotiable
                    f => f.Term(t => t.Field(d => d.Status).Value("active")),
                    f => q.MaxPrice is null ? f.MatchAll() : f.Range(r => r.NumberRange(n => n.Field(d => d.Price).Lte((double)q.MaxPrice)))
                )))
            .Sort(so => so.Field(f => f.CreatedAt, sf => sf.Order(SortOrder.Desc))), ct);

        if (!resp.IsValidResponse)
            return Error.Failure("Search.QueryFailed", resp.DebugInformation);

        var items = resp.Documents.Select(d => mapper.Map<ListingCardDto>(d)).ToList();
        return new PagedResult<ListingCardDto>(items, (int)resp.Total, q.Page, q.PageSize);
    }
}
```

## 6. Geo search patterns

- **Radius** — `geo_distance` on a `geo_point` field with `distance: "5km"` and origin.
- **Polygon** — `geo_shape` filter with `relation: intersects` and a polygon geometry.
- **Bounding box** — `geo_bounding_box` with top-left + bottom-right corners.
- **Sort by distance** — `_geo_distance` sort with origin + unit.
- Always combine geo with the tenant filter and at least one keyword filter to leverage the filter cache.

```csharp
var resp = await es.SearchAsync<ListingSearchDocument>(s => s
    .Index("listings")
    .Size(20)
    .Query(q => q.Bool(b => b
        .Must(m => string.IsNullOrWhiteSpace(text) ? m.MatchAll() : m.Match(t => t.Field(f => f.Title).Query(text!)))
        .Filter(
            f => f.Term(t => t.Field(d => d.TenantId).Value(user.TenantId.ToString())),  // tenant_id
            f => f.Term(t => t.Field(d => d.Status).Value("active")),
            // GEO: 5km radius around (lat, lng) on the geo_point field
            f => f.GeoDistance(g => g.Field(d => d.Location).Distance("5km").Location(GeoLocation.LatitudeLongitude(new(lat, lng)))),
            f => f.Range(r => r.NumberRange(n => n.Field(d => d.Price).Gte(minPrice).Lte(maxPrice)))
        )))
    // GEO: sort by ascending distance from the same origin
    .Sort(so => so.GeoDistance(g => g.Field(d => d.Location).Location(GeoLocation.LatitudeLongitude(new(lat, lng))).Order(SortOrder.Asc).Unit(DistanceUnit.Kilometers))), ct);
```

## 7. Pagination + sort

| Depth | Mechanism | Notes |
|---|---|---|
| ≤ 10,000 docs | `from` + `size` | Default for user-facing pagination |
| > 10,000 docs | `search_after` with stable tiebreaker (`_id`) | Cursor-based; no random page jumps |
| Export workloads | `scroll` API | NEVER for user-facing UI |

Page size: 20–50 default; hard cap at 100. Always specify a `Size(...)` — never return unbounded result sets.

```csharp
var resp = await es.SearchAsync<ListingSearchDocument>(s => s
    .Index("listings").Size(50)
    .Query(q => q.Bool(b => b.Filter(f => f.Term(t => t.Field(d => d.TenantId).Value(user.TenantId.ToString())))))
    .Sort(so => so.Field(f => f.CreatedAt, sf => sf.Order(SortOrder.Desc)).Field(f => f.Id, sf => sf.Order(SortOrder.Asc)))
    .SearchAfter(lastSort), ct);
```

## 8. Caching search results

Cache **only stable filter sets** — facet aggregations, "popular near you" with coarse-grained geo, configured-filter pages. Do NOT cache arbitrary full-text queries: the key space is huge and the cache hit rate is near zero.

When caching, wrap the `ISearchService` call in `HybridCache.GetOrCreateAsync` at the **query handler** level — see `hybridcache-patterns` §4. Do not embed cache logic inside the search service implementation; the service owns the query, the handler owns the cache decision.

```csharp
public async Task<ErrorOr<PagedResult<ListingCardDto>>> Handle(SearchPopularNearMeQuery q, CancellationToken ct)
{
    var key = $"yourcontext:search:popular:{q.Region}:page:{q.Page}";
    return await cache.GetOrCreateAsync(
        key,
        async token => await service.SearchAsync(q.AsServiceQuery(), token),
        new() { Expiration = TimeSpan.FromSeconds(60), LocalCacheExpiration = TimeSpan.FromSeconds(30) },
        tags: ["yourcontext:listing"],   // write-side write invalidates cached search pages
        cancellationToken: ct);
}
```

TTL ≤ 60s for search results (see `hybridcache-patterns` §3).

## 9. Reindex — alias-based zero downtime

Process:

1. Create a new physical index `<alias>_<timestamp>` with the latest mapping.
2. Bulk-index from PostgreSQL — paged read using a stable order.
3. Swap the alias atomically: one `UpdateAliases` action removing the old physical index and adding the new one.
4. Delete the old physical index after a retention window (e.g. 7 days for emergency rollback).

```csharp
public async Task<ErrorOr<Success>> SwapAliasAsync(string alias, string oldIndex, string newIndex, CancellationToken ct)
{
    var resp = await es.Indices.UpdateAliasesAsync(a => a
        .Actions(ac => ac
            .Remove(r => r.Alias(alias).Index(oldIndex))
            .Add(ad => ad.Alias(alias).Index(newIndex))), ct);
    return resp.IsValidResponse ? Result.Success : Error.Failure("Search.AliasSwapFailed", resp.DebugInformation);
}
```

The reindex job runs as a Hangfire job or a one-shot CLI runner (see `workflow-and-jobs-patterns` once that skill exists). Reindex on mapping changes or schema drift — never on every deployment.

## 10. Bulk indexing — initial seed + reindex

```csharp
foreach (var batch in docs.Chunk(1_000))
{
    // INDEX: bulk write — Polly handles transient retries on the HTTP client
    var resp = await es.BulkAsync(b => b.Index(physicalIndex)
        .IndexMany(batch, (op, doc) => op.Id(doc.Id)), ct);
    if (!resp.IsValidResponse || resp.Errors) return Error.Failure("Search.BulkFailed", resp.DebugInformation);
}
```

Wrap with retries on transient partial failures via Polly on the HTTP client (see `integration-adapter-patterns` §7 for idempotency-aware retry rules — bulk index calls are idempotent on document `_id`).

## 11. Error handling

4xx (mapping conflict, validation) → `Error.Validation`, do NOT retry. 429/503 (backpressure) → retry via Polly with backoff. Connection failure → retry with backoff, circuit-break after threshold. Always check `response.IsValidResponse` before reading `response.Documents`; on failure surface `Error.Failure` with `DebugInformation`. The ES HTTP client shares the resilience stack defined in `integration-adapter-patterns` §8.

## 12. Testing

Integration tests use Testcontainers (`Testcontainers.Elasticsearch`) — one container per test class or shared fixture. Mapping creation runs at fixture startup. Use `Refresh.WaitFor` on writes that need immediate searchability — never `Thread.Sleep`.

```csharp
[Fact]
public async Task Search_filters_by_tenant()
{
    var (tenantA, tenantB) = (Guid.NewGuid(), Guid.NewGuid());
    await es.IndexAsync(new ListingSearchDocument { Id = Guid.NewGuid(), TenantId = tenantA, Title = "A", Status = "active" },
        i => i.Index("listings").Refresh(Refresh.WaitFor));
    await es.IndexAsync(new ListingSearchDocument { Id = Guid.NewGuid(), TenantId = tenantB, Title = "B", Status = "active" },
        i => i.Index("listings").Refresh(Refresh.WaitFor));

    var svc = new ListingSearchService(es, new FakeUserContext { TenantId = tenantA }, mapper);
    var result = await svc.SearchAsync(new("", 1, 20, null), default);
    Assert.Single(result.Value.Items);
}
```

## 13. Anti-patterns

- Reading from Elasticsearch to update Elasticsearch — always read source of truth.
- Joining indices at query time — denormalize on the write side.
- Dynamic mapping in production — declare types explicitly.
- Missing `tenant_id` filter on a query — single-tenant assumption in a multi-tenant system.
- `scroll` API for user-facing pagination — use `search_after`.
- Caching full-text searches indiscriminately — low hit rate, big key space.
- Storing PII or secrets in indexed documents — redact at denormalization time.
- Treating Elasticsearch as a primary store — loss-of-data risk.
- Using deprecated clients (`NEST`, `Elasticsearch.Net`) — `Elastic.Clients.Elasticsearch` only.
- Falling back to PostgreSQL `LIKE` / PostGIS scan when ES is down — return `Error.Failure`, do not silently degrade.

## 14. Comment markers emitted by this skill

- `// INDEX:` — annotates an index/delete/bulk call to Elasticsearch.
- `// GEO:` — annotates a geo query parameter (point, polygon, radius, bounding box).

The canonical comment-markers index lives in `backend-feature-patterns §10`.

## 15. References

- `wolverine-patterns §6` — integration events drive the index handler.
- `persistence-patterns §4, §8` — read service for source-of-truth + PostGIS geo write side.
- `backend-feature-patterns §4, §7` — query handler shape + Mapster mapping.
- `hybridcache-patterns §3, §4` — cache stable search results, never full-text.
- `keycloak-patterns §2` — `IUserContext.TenantId` enforced on every query.
- `integration-adapter-patterns` — adapter authoring for the ES client (HTTP resilience, idempotency-aware retry, error mapping).
- `workflow-and-jobs-patterns` — reindex job runner (placeholder, Phase 4e).
- `.specify/memory/system-context.md` — project conventions for aliases, retention windows.
