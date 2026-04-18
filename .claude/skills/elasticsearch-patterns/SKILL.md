---
name: elasticsearch-patterns
description: "Load when: designing Elasticsearch indexes, writing search queries, implementing geo search (polygon/radius), or using Elastic.Clients.Elasticsearch in .NET. Loaded by: sk.datamodel, sk.contracts, sk.implement (backend)."
---

# Elasticsearch Patterns

## Purpose
Production patterns for Elasticsearch used as the search layer for the directory service. Primary use cases: geo-polygon and radius search, full-text listing search, faceted filtering, and autocomplete. Uses `Elastic.Clients.Elasticsearch` (.NET 10 official client).

## Core Rules

### Role in CQRS — Mandatory Search Read Model

Elasticsearch is the **only** read store for search-shaped queries in this system. See `csharp-clean-arch` (CQRS section) and `postgresql-patterns` (CQRS Data Access Split).

**Mandatory routing:**
* Any query that is geo-shaped (radius, polygon, bounding box), full-text, faceted, autocomplete, or paginated-by-relevance → must route through an `IQueryHandler<...>` that uses an `I{Entity}SearchRepository` backed by `Elasticsearch.Clients.Elasticsearch`.
* Search query handlers must **never** fall back to PostgreSQL for the search itself. If Elasticsearch is unavailable, the handler returns `Result.Failure(new ServiceUnavailableError(...))` — it does not silently degrade to a slower PostgreSQL `LIKE` or PostGIS scan.
* Single-entity-by-ID lookups, transactional reads, and reporting queries do **not** use Elasticsearch — those go to Redis cache or Dapper over PostgreSQL per `csharp-clean-arch`.
* See `csharp-clean-arch` (Read side) for the companion `I{Entity}ReadRepository` used for non-search reads — query handlers may inject either or both, but each Infrastructure impl class targets a single data store family (no class spans both ES and PostgreSQL).

**Write side:**
* Nothing writes to Elasticsearch from a CQRS command handler. Indexing happens exclusively in MassTransit consumers that subscribe to integration events published by the owning service via the transactional outbox (see `messaging-patterns`).
* The owning service's PostgreSQL is the source of truth; Elasticsearch is a derived projection. A full reindex must always be reproducible from PostgreSQL alone.

### Index Design
* Define **explicit mappings** for every index — never rely on dynamic mapping in production. Dynamic mapping guesses wrong types and creates unmapped fields silently.
* One index per entity type (`listings`, `vendors`, `areas`). Do not mix entity types in one index.
* Use index aliases for all read/write operations — never reference the index name directly in application code. Aliases enable zero-downtime reindexing.
* Index naming: `{service}-{entity}-{version}` (e.g., `listing-svc-listings-v1`). Alias: `{entity}` (e.g., `listings`).
* Design mappings based on access patterns first — only index fields you query or aggregate.

### Field Types — Critical Choices
| Need | Type | Notes |
|---|---|---|
| Geo search (lat/lon) | `geo_point` | Required for `geo_distance`, `geo_bounding_box`, `geo_polygon` |
| Full-text search | `text` with appropriate analyser | Analysed — not sortable |
| Exact match, filter, facet | `keyword` | Not analysed — case-sensitive |
| Text + exact match | `text` + `keyword` sub-field | `title.keyword` for sort/facet |
| Numbers (price, rating) | `double` / `integer` | For range filters and aggregations |
| Dates | `date` with format | ISO 8601 with timezone |
| Status / category | `keyword` | Never `text` |
| Nested objects (array of objects) | `nested` | Required for independent object queries |
| Autocomplete prefix | `search_as_you_type` or `edge_ngram` analyser | Purpose-built for prefix search |

### Geo Search — Primary Use Case
* Always use `geo_point` for location fields. Store as `{ lat, lon }` object.
* **Radius search** (`geo_distance` filter):
  ```json
  { "geo_distance": { "distance": "5km", "location": { "lat": 51.5, "lon": -0.1 } } }
  ```
* **Polygon search** (`geo_polygon` or `geo_shape` filter):
  ```json
  { "geo_polygon": { "location": { "points": [{"lat":51.5,"lon":-0.1}, ...] } } }
  ```
* Use `geo_shape` + `INTERSECTS` relation for complex polygon/multi-polygon area queries.
* Index geo_point fields with default mapping — no special index configuration needed; geo_point fields are automatically supported by geo queries.
* Sort by distance: use `_geo_distance` sort with `unit: "km"`, `order: "asc"`.
* Always combine geo filter with at least one keyword filter (`status: active`) to leverage Elasticsearch filter cache.

### Query Design
* Use `bool` query with `filter` context for non-scoring conditions (geo, status, price range) — filter results are cached, dramatically improving performance.
* Use `must` / `should` only when relevance scoring is needed (full-text search).
* Avoid leading wildcard queries (`*text`) — they bypass inverted index and do full scans.
* Avoid deep pagination (`from + size > 10,000`). Use `search_after` with a sort tiebreaker (`_id`) for cursor-based pagination.
* Limit `size` on every query. Never return unbounded result sets.
* Use `_source` includes to return only required fields — reduces network payload.

### Aggregations
* Always add `size: 0` when you only need aggregation results (no hits).
* `terms` aggregation for facets (categories, statuses). Set `size` explicitly (default 10 is rarely correct).
* `range` aggregation for price brackets.
* `geo_distance` aggregation for "listings within X km" counts per distance band.
* Sub-aggregations are expensive — limit nesting to 2 levels.

### Index Lifecycle & Shard Sizing
* Target shard size: 20–40GB. Over-sharding is worse than under-sharding for small indices.
* Primary shards: set at index creation — cannot be changed without reindexing. Plan for growth.
* Replica shards: 1 replica minimum for production HA. Replicas serve reads.
* Use ILM (Index Lifecycle Management) for time-series indices (audit logs, activity streams).
* Hot phase: active writes/reads. Warm phase: read-only, shrink + force-merge. Delete phase: retention expiry.

### .NET Client (`Elastic.Clients.Elasticsearch`)
* Register as singleton: `ElasticsearchClient` is thread-safe.
* Use strongly-typed requests and responses — never raw JSON strings in application code.
* Always check `response.IsValidResponse` before accessing `response.Documents`.
* Use `CancellationToken` on every async call.
* Bulk indexing: use `BulkAsync` for batch writes. Optimal batch: 5–15MB payload. Check `response.Errors` after each bulk call.
* Do not catch generic `Exception` — handle `ElasticsearchClientException` specifically for client errors.

### Synchronisation Strategy
* Source of truth: PostgreSQL. Elasticsearch is a derived read model — never write directly to ES from clients.
* Sync pattern: MassTransit consumer subscribes to integration events published by the owning service **via the transactional outbox** (see `messaging-patterns` — Transactional Outbox). The owning service's command handler commits aggregate state and the outbox row in one PostgreSQL transaction; the relay publishes; the indexer consumer (`ListingActivated`, `ListingUpdated`, `ListingDeleted`) updates the ES index. There is no direct Publish from the command handler — the outbox is the single bridge between the write side and ES.
* Indexer consumers must be idempotent (see `messaging-patterns` — Delivery Guarantee & Idempotency). At-least-once delivery means the same event may arrive twice; rely on `IndexAsync` with the document ID acting as a natural dedup key, or check the version field on the document.
* On consumer failure: dead-letter queue + Hangfire retry job for reindexing.
* Full reindex: zero-downtime using alias swap — write to new index, then swap alias atomically.
* Consistency model: **eventual**. Document this explicitly in the unit knowledge base. Search results may lag domain state by seconds.

### Security
* Never expose Elasticsearch directly to the internet or frontend. All queries routed through the backend service.
* Use role-based access control: one Elasticsearch role per service with minimal index privileges (read for search service, write for indexer).
* No dynamic scripts (`script` queries) from user input — scripted queries allow arbitrary code execution.

## Patterns / Examples

### Index mapping (listings)
```csharp
await client.Indices.CreateAsync("listing-svc-listings-v1", c => c
    .Mappings(m => m
        .Properties<ListingDocument>(p => p
            .Keyword(k => k.Name(f => f.PublicId))
            .Text(t => t.Name(f => f.Title).Fields(ff => ff.Keyword(k => k.Name("keyword"))))
            .Text(t => t.Name(f => f.Description))
            .Keyword(k => k.Name(f => f.Status))
            .Keyword(k => k.Name(f => f.Category))
            .Double(d => d.Name(f => f.Price))
            .GeoPoint(g => g.Name(f => f.Location))
            .Date(d => d.Name(f => f.CreatedAt))
        )
    )
    .Settings(s => s.NumberOfShards(2).NumberOfReplicas(1))
);
```

### Geo + full-text + facet query
```csharp
var response = await client.SearchAsync<ListingDocument>(s => s
    .Index("listings")
    .Size(20)
    .Source(src => src.Includes(i => i.Fields(
        f => f.PublicId, f => f.Title, f => f.Price, f => f.Location, f => f.Status)))
    .Query(q => q.Bool(b => b
        .Must(m => m.Match(mt => mt.Field(f => f.Title).Query(searchTerm)))
        .Filter(
            f => f.Term(t => t.Field(f => f.Status).Value("active")),
            f => f.GeoDistance(g => g
                .Field(f => f.Location)
                .Location(new GeoLocation(lat, lon))
                .Distance("10km")),
            f => f.Range(r => r.NumberRange(n => n.Field(f => f.Price).Gte(minPrice).Lte(maxPrice)))
        )
    ))
    .Sort(so => so.GeoDistance(g => g
        .Field(f => f.Location)
        .Location(new GeoLocation(lat, lon))
        .Order(SortOrder.Asc)
        .Unit(DistanceUnit.Kilometers)))
    .Aggregations(a => a
        .Terms("categories", t => t.Field(f => f.Category).Size(20))
    ),
    cancellationToken
);

if (!response.IsValidResponse)
    throw new SearchException($"ES query failed: {response.DebugInformation}");
```

### Bulk indexing on domain event
```csharp
public class ListingIndexConsumer(ElasticsearchClient esClient, ILogger<ListingIndexConsumer> logger)
    : IConsumer<ListingActivated>
{
    public async Task Consume(ConsumeContext<ListingActivated> context)
    {
        var doc = await BuildDocumentAsync(context.Message.ListingId, context.CancellationToken);
        var response = await esClient.IndexAsync(doc, i => i.Index("listings").Id(doc.PublicId), context.CancellationToken);

        if (!response.IsValidResponse)
            logger.LogError("Failed to index listing {ListingId}: {Error}", doc.PublicId, response.DebugInformation);
    }
}
```

## When to Use
* Designing the search index for any searchable entity
* Implementing geo search (radius, polygon, bounding box)
* Full-text search, autocomplete, faceted filtering
* `sk.datamodel` for units with a search access pattern
* `sk.implement` for search service or indexer consumer implementation

## When NOT to Use
* Transactional data storage → PostgreSQL
* Simple exact-match lookups → PostgreSQL or Redis
* Audit logs or time-series metrics → PostgreSQL with partitioning or a dedicated TSDB
* Ad-hoc analytics queries → use PostgreSQL with read replica or a reporting tool
