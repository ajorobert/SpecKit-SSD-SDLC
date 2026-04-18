---
name: postgresql-patterns
description: "Load when: designing schemas, writing migrations, choosing data types, defining indexes, or reviewing PostgreSQL table design. Loaded by: sk.datamodel, sk.implement (backend)."
---

# PostgreSQL Patterns

## Purpose
Production schema design and data access patterns for PostgreSQL used across all services. Covers data types, indexing strategy, partitioning, constraints, EF Core migration rules, and safe schema evolution. Applies to all service databases on the shared PostgreSQL cluster.

## Core Rules

### Primary Keys
* Use `BIGINT GENERATED ALWAYS AS IDENTITY` as default — efficient, sequential, no gaps concern.
* Use `UUID` (v7 with `gen_random_uuid()` or `uuidv7()`) only when global uniqueness, opacity, or external reference is required (e.g., listing IDs exposed in URLs).
* Never use `SERIAL` — deprecated pattern. Never use `UUID` v4 for high-volume insert tables without measuring index fragmentation.

### Data Types — Non-Negotiable
| Use | Never Use |
|---|---|
| `TIMESTAMPTZ` | `TIMESTAMP` (no timezone) |
| `TEXT` | `VARCHAR(n)` or `CHAR(n)` |
| `NUMERIC(p,s)` | `MONEY`, `FLOAT`, `DOUBLE PRECISION` for financial values |
| `BIGINT` | `INT` for IDs or counts that may exceed 2B |
| `BOOLEAN NOT NULL` | nullable boolean for two-state flags |
| `BIGINT GENERATED ALWAYS AS IDENTITY` | `SERIAL` |
| `TEXT + CHECK (LENGTH(...) <= n)` | `VARCHAR(n)` |
| `CREATE TYPE ... AS ENUM` | magic strings for stable value sets |

* Use `TEXT` for evolving business enums (categories, statuses that business will change). Use `CREATE TYPE AS ENUM` for stable values (cardinal directions, ISO codes).
* Use `now()` for transaction time; `clock_timestamp()` for wall-clock time within a transaction.
* Store money as `NUMERIC(14,4)` — four decimal places for currency arithmetic safety.

### Naming Conventions
* Table names: `snake_case`, plural (e.g., `listings`, `user_sessions`).
* Column names: `snake_case`. Foreign keys: `{referenced_table_singular}_id` (e.g., `owner_id` references `users`).
* Indexes: `idx_{table}_{columns}` (e.g., `idx_listings_area_id_status`).
* Constraints: `chk_{table}_{constraint}`, `uq_{table}_{columns}`, `fk_{table}_{ref_table}`.

### Normalization
* Normalize to 3NF by default. Eliminate update anomalies.
* Denormalize only for measured, high-ROI read paths — document the reason and the query it optimizes. Denormalized columns require a trigger or application-layer sync strategy — document which.

### Indexing — Design for Access Patterns First
* **B-tree** (default): equality and range queries, ORDER BY, BETWEEN.
* **GIN**: JSONB containment/existence, full-text search (`tsvector`), array containment.
* **GiST**: geo types (PostGIS geometry, ranges), exclusion constraints.
* **BRIN**: large append-only tables where disk order correlates with the query column (e.g., time-series `created_at`). Tiny overhead, poor selectivity.
* **Partial index**: hot subsets — `CREATE INDEX idx_listings_active_area ON listings (area_id) WHERE status = 'active'`.
* **Covering index**: avoid heap access — `CREATE INDEX ON listings (owner_id) INCLUDE (title, status)`.
* **Expression index**: `CREATE INDEX ON users (LOWER(email))` — expression must match WHERE clause exactly.
* **Rule**: every query pattern in the unit's Access Patterns section must have a corresponding index. No index = no query in production.
* Always index foreign key columns manually — PostgreSQL does not auto-index them.
* `CREATE INDEX CONCURRENTLY` for adding indexes to live tables — cannot run inside a transaction.

### Geo / Spatial (PostGIS)
* Enable PostGIS extension: `CREATE EXTENSION IF NOT EXISTS postgis;`
* Use `GEOMETRY(Point, 4326)` for lat/lon coordinates (WGS84 SRID 4326).
* Use `GEOMETRY(Polygon, 4326)` for area boundaries.
* Index geometry columns with GiST: `CREATE INDEX ON listings USING GIST (location)`.
* Radius search: `ST_DWithin(location, ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography, :radius_meters)`.
* Polygon containment: `ST_Within(location, ST_GeomFromGeoJSON(:polygon_geojson))`.
* Store radius distances in metres. Accept lat/lon from clients in decimal degrees.

### Partitioning
* Required when a table is projected to exceed 100M rows or has high write throughput with time-based access patterns.
* **RANGE** on `created_at` for time-series data (events, logs, audit trails) — monthly or weekly partitions.
* **LIST** on `tenant_id` for multi-tenant tables where tenant isolation is required.
* **HASH** for even distribution without a natural key.
* Always use declarative partitioning (`PARTITION BY`). Never table inheritance.
* Create partitions ahead of time (at least 2 periods ahead). Automate with pg_partman or Hangfire job.

### Constraints
* `NOT NULL` on all columns that are semantically required — never nullable as a lazy default.
* `DEFAULT` for common values: `DEFAULT now()`, `DEFAULT FALSE`, `DEFAULT '{}'::jsonb`.
* `CHECK` constraints for business rules local to a row: `CHECK (price > 0)`, `CHECK (status IN ('active','inactive','pending'))`.
* `FOREIGN KEY` with explicit `ON DELETE` action: `RESTRICT` (default, fail loudly), `CASCADE` (only for ownership), `SET NULL` (for optional references).
* `DEFERRABLE INITIALLY DEFERRED` for circular FK dependencies only.
* `EXCLUDE USING GIST` for no-overlap constraints (e.g., booking time slots per resource).

### JSONB
* Use for optional or semi-structured attributes — not for core queryable fields.
* Index with GIN: `CREATE INDEX ON listings USING GIN (attributes)`.
* Use `jsonb_path_ops` variant for containment-only indexes (smaller).
* Extract frequently queried JSONB fields to a generated column for B-tree indexing:
  ```sql
  ALTER TABLE listings ADD COLUMN category TEXT GENERATED ALWAYS AS (attributes->>'category') STORED;
  CREATE INDEX ON listings (category);
  ```
* Never store core business data (price, status, owner) in JSONB — use proper columns.

### EF Core Migration Rules
* One migration per logical change. Never batch unrelated changes in one migration.
* `CREATE INDEX CONCURRENTLY` is not transactional — use `migrationBuilder.Sql(...)` with `suppressTransaction: true`.
* Never add a `NOT NULL` column without a `DEFAULT` to a table with existing rows — causes full table rewrite.
* For volatile defaults (`gen_random_uuid()`, `now()`): add nullable, backfill, then add `NOT NULL` constraint in separate migration steps.
* Test migrations with `BEGIN; -- run migration; ROLLBACK;` against a production-size dataset in staging before applying.
* Never modify existing migrations after they have been applied to any environment.

### Row-Level Security (Multi-Tenancy)
```sql
ALTER TABLE listings ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON listings
    USING (tenant_id = current_setting('app.tenant_id')::uuid);
```
* Set `app.tenant_id` at session start via `SET LOCAL app.tenant_id = '...'`.
* Apply to all tables containing tenant data. EF Core global query filter is an additional safeguard, not a replacement.

## Patterns / Examples

### Standard entity table
```sql
CREATE TABLE listings (
    listing_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    public_id    UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE, -- exposed in URLs
    owner_id     BIGINT NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
    tenant_id    UUID NOT NULL,
    title        TEXT NOT NULL,
    description  TEXT,
    price        NUMERIC(14,4) NOT NULL CHECK (price >= 0),
    status       TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','active','inactive','archived')),
    location     GEOMETRY(Point, 4326),
    attributes   JSONB NOT NULL DEFAULT '{}',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at   TIMESTAMPTZ -- soft delete
);

-- Required indexes
CREATE INDEX idx_listings_owner_id ON listings (owner_id);
CREATE INDEX idx_listings_tenant_status ON listings (tenant_id, status) WHERE deleted_at IS NULL;
CREATE INDEX idx_listings_location ON listings USING GIST (location);
CREATE INDEX idx_listings_created_at ON listings (created_at);
CREATE INDEX idx_listings_attributes ON listings USING GIN (attributes);
```

### Geo radius query
```sql
SELECT listing_id, title, price,
       ST_Distance(location::geography, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography) AS distance_m
FROM listings
WHERE status = 'active'
  AND deleted_at IS NULL
  AND ST_DWithin(
        location::geography,
        ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography,
        $3  -- radius in metres
      )
ORDER BY distance_m
LIMIT 50;
```

### Upsert pattern
```sql
INSERT INTO user_search_preferences (user_id, area_polygon, radius_m, updated_at)
VALUES ($1, ST_GeomFromGeoJSON($2), $3, now())
ON CONFLICT (user_id)
DO UPDATE SET
    area_polygon = EXCLUDED.area_polygon,
    radius_m     = EXCLUDED.radius_m,
    updated_at   = EXCLUDED.updated_at;
```

## When to Use
* `sk.datamodel` — designing any new table or schema change
* `sk.implement` — writing EF Core migrations, Dapper queries, or repository implementations
* `sk.review` — reviewing schema changes or data access code

## When NOT to Use
* Elasticsearch index design (see `elasticsearch-patterns`)
* Redis data structure design (see `redis-patterns`)
* Strapi CMS schema (managed by Strapi's own migration system)
