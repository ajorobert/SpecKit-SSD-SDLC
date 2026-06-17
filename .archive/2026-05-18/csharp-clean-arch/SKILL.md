---
name: csharp-clean-arch
description: "Load when: implementing or reviewing C# .NET 10 backend code inside a single bounded context. Clean Architecture layers, DDD aggregates / value objects / domain events, CQRS marker interfaces, write-via-aggregate / read-via-shape repository split, EF Core writes + Dapper/Elasticsearch reads, Result<T> pattern, async correctness, xUnit testing. HTTP endpoints in fastendpoints-patterns; outbox mechanics in wolverine-patterns. Project structure rules live in .specify/memory/system-context.md."
---

# C# Clean Architecture (.NET 10) — Within One Bounded Context

## Purpose
Production patterns for a C# .NET 10 backend service implementing **one bounded context**. Enforces Clean Architecture layer separation, DDD aggregate discipline, CQRS at the Application layer, and DDIA-aligned access-pattern-driven data access — so AI-generated code across features stays consistent and reviewable.

**Scope is intentionally narrow** — *inside* a single bounded context. Everything below assumes you are inside one `*.Domain` / `*.Application` / `*.Infrastructure` / `*.Api` set:
* Project structure rules live in `.specify/memory/system-context.md`.
* For HTTP endpoints (FastEndpoints, ProblemDetails mapping, idempotency-key) → `fastendpoints-patterns`.
* For outbox mechanics, message contracts, consumer topology → `wolverine-patterns`.
* For OTel/Serilog wiring and trace propagation → `observability-backend`.

## Core Rules

### Layer Boundaries (within this bounded context)
* **Domain**: Aggregate roots, entities, value objects, domain events, repository **interfaces**, domain services. Zero infrastructure or framework dependencies. **Never reference EF Core, Wolverine, or any library** — Domain compiles with only `Microsoft.NET.Sdk` references.
* **Application**: Use cases (commands/queries), application services, DTOs, FluentValidation validators, read-repository interfaces, integration-event interfaces. References Domain. No direct DB access — only through interfaces.
* **Infrastructure**: EF Core `DbContext` and write repository implementations, Dapper read repository implementations, Elasticsearch search repository implementations, Redis decorators (Scrutor), Wolverine consumers and message handlers, Hangfire job classes, HTTP clients for external services, Elsa workflow activities. Implements interfaces declared in Domain/Application.
* **API**: FastEndpoints — **see `fastendpoints-patterns`**. Application handlers return `Result<T>`; the API layer maps to HTTP. No MVC controllers in this stack.
* **Dependency direction**: API → Application → Domain. Infrastructure → Application + Domain (implements their interfaces). Nothing in Application/Domain references Infrastructure or API.
* **Namespace convention**: `{Context}.{Layer}.{Aggregate}` — e.g., `Listing.Application.Listings.Activate`.

Project structure rules live in `.specify/memory/system-context.md`.

### Folder Structure (one bounded context)
Aggregates organize as **folders** under `Domain/` and `Application/`; never as separate projects. One `*.Api` project per bounded context (also see `fastendpoints-patterns`).

```
src/Listing/
  Listing.Domain/
    Listings/
      Listing.cs                    // aggregate root
      ListingId.cs                  // value object
      ListingActivated.cs           // domain event
      IListingWriteRepository.cs    // interface (impl in Infrastructure)
    Shared/                          // value objects shared within THIS context only
      Money.cs
      EmailAddress.cs
  Listing.Application/
    Listings/
      Activate/
        ActivateListingCommand.cs
        ActivateListingHandler.cs
        ActivateListingValidator.cs
      GetById/
        GetListingByIdQuery.cs
        GetListingByIdHandler.cs
      IListingReadRepository.cs     // read-shape interface
      IListingSearchRepository.cs   // search-shape interface
  Listing.Infrastructure/
    Persistence/                    // EF Core DbContext + write repos + Dapper read repos
    Search/                         // Elasticsearch impl of search repo
    Messaging/                      // Wolverine consumers, integration-event publishers
    Migrations/                     // EF Core migrations — this context's schema only
  Listing.Api/                      // FastEndpoints — see fastendpoints-patterns
```

### Domain Layer — DDD Aggregate Rules
The aggregate is the unit of consistency and the thing we protect from arbitrary state changes.

* **Aggregates have one root entity.** External code (handlers, repositories) references the root only — never inner entities directly. Inner entities are reached through the root and only mutated through root methods.
* **Invariants are enforced inside aggregate methods, never in handlers or services.** A handler that performs business validation has logic in the wrong place.
* **Aggregate constructors are private.** Creation goes through static factory methods that enforce invariants:
  ```csharp
  private Listing(ListingId id, OwnerId ownerId, Money price, ...) { ... }
  public static Listing Create(OwnerId ownerId, string title, Money price, GeoPoint location)
  {
      // factory enforces invariants on creation
      if (string.IsNullOrWhiteSpace(title)) throw new DomainException("Title required");
      var listing = new Listing(ListingId.New(), ownerId, price, ...);
      listing.RaiseEvent(new ListingCreated(listing.Id));
      return listing;
  }
  ```
* **Aggregates raise domain events via a base class** (`AggregateRoot.RaiseEvent(...)`). Events are queued on the aggregate; the **Infrastructure outbox** dispatches them after the transaction commits. The domain itself never publishes — it only declares.
* **Value objects** are immutable `record` types with structural equality. Wrap primitives that carry meaning: `ListingId`, `OwnerId`, `EmailAddress`, `Money`, `GeoPoint`. Never expose raw `Guid`/`string`/`decimal` on aggregate boundaries when a value object would communicate intent.
* **Domain exceptions** signal invariant violations inside aggregate methods. They are translated to `Result.Failure` at the Application layer; they never escape to the API layer.

### Domain Events vs Integration Events
* **Domain events** (live in `*.Domain/*/Events/`) are raised by aggregates and consumed *inside* the same bounded context — e.g., `ListingActivated` triggers a Listing Application handler that updates a read model. They use the local message dispatcher.
* **Integration events** (live in `Shared.Contracts/`) cross bounded contexts. Project structure rules live in `.specify/memory/system-context.md`.
* The **Infrastructure layer** is responsible for translating domain events to integration events when crossing context boundaries via the outbox. The aggregate raises a domain event; an Infrastructure handler decides whether (and how) to publish a corresponding integration event.

### Application Layer — CQRS

> **Dispatcher note**: Wolverine is the dispatcher. A Wolverine handler is a plain class with a `Handle`/`HandleAsync` method discovered by convention — see `wolverine-patterns` §2-3. The marker interfaces below are a transitional shape; the example block is owned by Phase 3 and is left as a pre-Wolverine reference until then.

Every use case is either a **command** (changes state, returns `Result` or `Result<TId>`) or a **query** (reads data, returns `Result<TReadModel>`). They never share handlers, never share repositories, and never share the same data path.

**Marker interfaces** (defined in Application):
<!-- PHASE-3-FIX: example uses pre-Wolverine MediatR `IRequest`/`IRequestHandler` shape; rewrite when this skill is updated in Phase 3. -->
```csharp
public interface ICommand               : IRequest<Result> { }
public interface ICommand<TResponse>    : IRequest<Result<TResponse>> { }
public interface IQuery<TResponse>      : IRequest<Result<TResponse>> { }

public interface ICommandHandler<TCommand>             : IRequestHandler<TCommand, Result>
    where TCommand : ICommand { }
public interface ICommandHandler<TCommand, TResponse>  : IRequestHandler<TCommand, Result<TResponse>>
    where TCommand : ICommand<TResponse> { }
public interface IQueryHandler<TQuery, TResponse>      : IRequestHandler<TQuery, Result<TResponse>>
    where TQuery : IQuery<TResponse> { }
```

**Write side (commands):**
* Loads aggregate roots through `I{Aggregate}WriteRepository` — methods return rich domain entities, never DTOs.
* Mutates aggregates by invoking domain methods (`listing.Activate()`), never by setting properties.
* Persists through EF Core via Unit of Work; aggregate-raised domain events are written to the outbox in the same transaction (see `wolverine-patterns` for outbox mechanics).
* Write repositories expose: `GetByIdAsync`, `AddAsync`, `UpdateAsync`. **Never list/search/projection methods** — those go on read or search repositories.

**Read side (queries):**
* Two read-side base interfaces exist, picked by the **shape** of the access pattern (DDIA: model the access pattern, not the entity):

  | Interface | Backed by | Used for |
  |---|---|---|
  | `I{Entity}ReadRepository` | Dapper over PostgreSQL, optionally wrapped by `HybridCache.GetOrCreateAsync` at the query-handler call site (see `hybridcache-patterns`) | Single entity by ID, paged lists with deterministic filters, reporting projections, joins for read DTOs. Reads of the *current state* of a known entity. |
  | `I{Entity}SearchRepository` | `Elastic.Clients.Elasticsearch` against the search index (mandatory — never PostgreSQL for search) | Geo (radius/polygon/bounding box), full-text, faceted filtering, autocomplete, relevance-paginated results. Reads where the question is "find entities matching shape X." |

* A query handler may inject **either or both**. Most handlers inject one. Aggregating handlers ("search results, then enrich each hit with detail") may inject both, but composition usually belongs in the BFF — see `bff-patterns`.
* Each Infrastructure impl class targets **one** data store. `DapperListingReadRepository` does not touch Elasticsearch. `ElasticsearchListingSearchRepository` does not touch PostgreSQL.
* **Caching is opt-in per query handler** via `HybridCache.GetOrCreateAsync` wrapping the Dapper read (see `hybridcache-patterns` §4 and §7). Never inject raw Redis types (`IConnectionMultiplexer`, `IDatabase`) or legacy `IDistributedCache` into application code — `HybridCache` is the only cache API in handlers; raw Redis is confined to port adapters (see `hybridcache-patterns` §10).
* Latest entity state with no caching may use EF Core `.AsNoTracking()` inside a `I{Entity}ReadRepository` impl, but this is the exception — Dapper is the default.
* Read repositories return DTOs/records — never aggregate roots, never `IQueryable`.
* Read models are decoupled from domain entities — they are reshaped for the consumer.

**Hard rules:**
* A handler that writes must not return read DTOs. Return `Result<Guid>` (new ID) or `Result` (no payload). Clients re-fetch via the query side.
* A read repository must not be injected into a command handler. A write repository must not be injected into a query handler.
* The same physical table may back both write and read — the *interfaces* and the *handlers* are split. CQRS here is logical, not necessarily physical separation of databases.

### Handler Purity
Handlers orchestrate; they do not contain domain logic.

* **Command handler body** is at most: load aggregate → invoke aggregate method(s) → save → return `Result`. If a handler grows beyond ~20 lines, the missing logic likely belongs in the aggregate or a domain service.
* **Query handler body** is at most: call read repo → map to `Result`.
* No `if (listing.Status == ...)` branches in handlers — that's a domain invariant; move it inside the aggregate method.
* No try/catch around domain calls — domain exceptions translate to `Result.Failure` via Wolverine middleware or a thin guard at the handler boundary.

### Validation Layering
* **Input validation** (shape, format, ranges) → FluentValidation in Application, runs as Wolverine middleware before the handler. Examples: "title is non-empty and ≤ 200 chars", "price ≥ 0", "page ≥ 1".
* **Business rules** (invariants, state transitions) → inside the aggregate. Examples: "cannot activate a listing without a verified owner", "cannot reduce price below cost".
* **Never duplicate a business rule in a validator.** Never put input shape checks in the aggregate.
* Validators run before the handler — failures produce `Result.Failure(ValidationError)` (mapped to 400 by `fastendpoints-patterns`). The handler assumes shape is already valid.

### Result Pattern
* All application handlers return `Result<T>` or `Result` for operations that can fail in expected ways.
* Use the canonical six-failure taxonomy: `NotFound`, `Validation` (= `Invalid`), `Conflict`, `Forbidden`, `Unauthorized`, `Unexpected` (= `Error`/`CriticalError`). No other failure shapes.
* Use exceptions only for **unexpected** infrastructure failures or programming errors (bugs).
* Never throw domain exceptions across the API boundary — they translate to `Result.Failure` at the handler boundary.
* `Ardalis.Result` is the chosen library; the API layer maps `ResultStatus` → HTTP via `fastendpoints-patterns`'s `SendResultAsync`.

### Data Access (DDIA-aligned)
* **Write side is always through the aggregate via EF Core.** No bulk SQL writes, no Dapper writes, no raw SQL writes from handlers. The only path that mutates state is `repo.Update(aggregate)` after invoking aggregate methods.
* **Read side picks the store by access shape** (see CQRS table above). Caching is opt-in via Scrutor decorator on `I{Entity}ReadRepository`.
* **Outbox table is per bounded context**, in the same database as the write store, written in the same transaction as the aggregate. (Mechanics: `wolverine-patterns`.)
* **Migrations belong to Infrastructure** and run only against this context's schema. Never modify another context's schema — that's a contract break. Project structure rules live in `.specify/memory/system-context.md`.
* Always use `.AsNoTracking()` for any EF Core query in a query handler.
* Apply EF Core global query filters for soft deletes (`IsDeleted`) and multi-tenancy (`TenantId`) — declared once in `DbContext.OnModelCreating`.
* Repositories expose domain-semantic methods (`GetActiveListingsForAreaAsync`), not `IQueryable`.
* Use the Unit of Work pattern on the **write side only** for transaction coordination across multiple write repositories.

### Dependency Injection (.NET 10)
* Use primary constructor syntax — the idiomatic .NET 10 pattern:
  ```csharp
  public class ActivateListingHandler(
      IListingWriteRepository repo,
      IUnitOfWork uow,
      ILogger<ActivateListingHandler> logger) { }
  ```
* Register per layer via extension methods: `services.AddDomain()`, `services.AddApplication()`, `services.AddInfrastructure(config)`, `services.AddApi()`.
* Lifetimes: **Scoped** for `DbContext` and repositories; **Singleton** for thread-safe stateless services; **Transient** for lightweight non-shared utilities.
* Never use `new` to instantiate services. Never use service locator pattern.
* Use `IOptions<T>` with `ValidateDataAnnotations()` and `ValidateOnStart()` for all configuration.

### Async Patterns (.NET 10)
* Async all the way — never block an async call chain.
* Always accept and forward `CancellationToken` from API down to repository.
* Use `Task.WhenAll` for independent parallel I/O operations.
* No `Task.Run` for I/O work — it wastes thread pool threads. Only for genuinely CPU-bound offloading.
* Do NOT use `ConfigureAwait(false)` in application/API code. Only library authors need it.
* Never use `.Result`, `.Wait()`, or `.GetAwaiter().GetResult()` — deadlocks in ASP.NET context.
* Never use `async void` except for event handlers (unavoidable).
* Use `ValueTask<T>` for hot-path operations that frequently complete synchronously.

### Error Handling & Logging
* Structured logging via `Microsoft.Extensions.Logging` (Serilog provider — see `observability-backend`). No unstructured plain text in production.
* Required log fields: `service`, `trace_id`, `span_id`, entity IDs relevant to the operation, `level`, `message`. (Trace fields are auto-enriched — see `observability-backend`.)
* WARN for expected degraded states (retry, cache miss, fallback). ERROR for unexpected failures.
* Never log passwords, tokens, PII, or payment data — PII redaction is enforced by Serilog destructuring policy (see `observability-backend`).
* Global exception handling middleware catches unhandled exceptions — services should not swallow them silently.

### Testing
* xUnit for test runner. Moq for mocking dependencies.
* AAA pattern strictly (Arrange / Act / Assert).
* `WebApplicationFactory<TProgram>` for integration tests against real PostgreSQL via Testcontainers (no mocked DB).
* **Unit test**: domain logic (aggregate methods, value objects, domain services), Application command/query handlers, validators.
* **Integration test**: repository implementations, FastEndpoints endpoints, Wolverine consumers.
* **Coverage targets** (aspirational, not CI gates): Domain ~95%, Application ~90%, Infrastructure ~70%. Do not chase coverage on EF mapping, DI registration, or trivial DTO code.
* Use `[Theory]` with `[InlineData]` for boundary and equivalence class testing.

### Code Quality (guidelines, not gates)
* Keep methods under ~30 lines and parameter counts under 4. Beyond that, extract — but the threshold is a smell, not a CI gate.
* SOLID: single responsibility enforced by layer structure; open/closed via extension points; LSP/ISP via focused interfaces; DIP via constructor injection.
* Use `record` types for immutable DTOs, value objects, and commands/queries.
* No static mutable state in services. No ambient context patterns.
* Public method names: verb-noun describing intent (`CreateListing`, `GetActiveAreaListings`).

## Patterns / Examples

### Aggregate root with factory + invariant + domain event
```csharp
// Listing.Domain/Listings/Listing.cs
public sealed class Listing : AggregateRoot
{
    public ListingId Id { get; }
    public OwnerId  OwnerId { get; }
    public Money    Price { get; private set; }
    public ListingStatus Status { get; private set; }

    private Listing(ListingId id, OwnerId ownerId, Money price)
    {
        Id = id; OwnerId = ownerId; Price = price; Status = ListingStatus.Draft;
    }

    public static Listing Create(OwnerId ownerId, Money price)
    {
        if (price.Amount <= 0) throw new DomainException("Price must be positive");
        var listing = new Listing(ListingId.New(), ownerId, price);
        listing.RaiseEvent(new ListingCreated(listing.Id, ownerId));
        return listing;
    }

    public void Activate()
    {
        if (Status != ListingStatus.Draft)
            throw new DomainException($"Cannot activate listing in status {Status}");
        Status = ListingStatus.Active;
        RaiseEvent(new ListingActivated(Id));
    }
}
```

### Value object (immutable record with structural equality)
```csharp
// Listing.Domain/Shared/Money.cs
public readonly record struct Money(decimal Amount, string Currency)
{
    public static Money Zero(string currency) => new(0m, currency);
    public Money Add(Money other)
    {
        if (Currency != other.Currency) throw new DomainException("Currency mismatch");
        return new Money(Amount + other.Amount, Currency);
    }
}
```

### Command + Handler (write side)
```csharp
// Listing.Application/Listings/Activate/ActivateListingCommand.cs
public record ActivateListingCommand(Guid ListingId) : ICommand;

// Listing.Application/Listings/Activate/ActivateListingHandler.cs
public class ActivateListingHandler(
    IListingWriteRepository repo,
    IUnitOfWork uow,
    ILogger<ActivateListingHandler> logger)
    : ICommandHandler<ActivateListingCommand>
{
    public async Task<Result> Handle(ActivateListingCommand cmd, CancellationToken ct)
    {
        var listing = await repo.GetByIdAsync(new ListingId(cmd.ListingId), ct);
        if (listing is null) return Result.NotFound("Listing not found");

        listing.Activate();                 // invariants live in the aggregate
        await uow.CommitAsync(ct);          // outbox row written in same transaction
        logger.LogInformation("Listing {ListingId} activated", listing.Id);
        return Result.Success();
    }
}

// Listing.Application/Listings/Activate/ActivateListingValidator.cs
public class ActivateListingValidator : AbstractValidator<ActivateListingCommand>
{
    public ActivateListingValidator()
    {
        RuleFor(x => x.ListingId).NotEmpty();
    }
}
```

### Query + Handler (read side)
```csharp
public record GetListingDetailQuery(Guid ListingId) : IQuery<ListingDetailDto>;

public class GetListingDetailHandler(IListingReadRepository reads)
    : IQueryHandler<GetListingDetailQuery, ListingDetailDto>
{
    public async Task<Result<ListingDetailDto>> Handle(GetListingDetailQuery q, CancellationToken ct)
    {
        var dto = await reads.GetDetailAsync(q.ListingId, ct);
        return dto is null
            ? Result<ListingDetailDto>.NotFound("Listing not found")
            : Result.Success(dto);
    }
}
```

### Search Query + Handler (read side, search-shaped)
```csharp
public record SearchListingsQuery(GeoPolygon Area, string? Text, int Page) : IQuery<ListingSearchPage>;

public class SearchListingsHandler(IListingSearchRepository search)
    : IQueryHandler<SearchListingsQuery, ListingSearchPage>
{
    public async Task<Result<ListingSearchPage>> Handle(SearchListingsQuery q, CancellationToken ct)
    {
        var page = await search.SearchAsync(q.Area, q.Text, q.Page, ct);
        return Result.Success(page);
    }
}
```

### Repository Interfaces — split by side AND by read shape
```csharp
// Listing.Domain/Listings/IListingWriteRepository.cs — aggregate-oriented, no EF Core reference
public interface IListingWriteRepository
{
    Task<Listing?> GetByIdAsync(ListingId id, CancellationToken ct);   // load aggregate for mutation
    Task AddAsync(Listing listing, CancellationToken ct);
    Task UpdateAsync(Listing listing, CancellationToken ct);
}

// Listing.Application/Listings/IListingReadRepository.cs — entity-shaped reads of current state
// Backed by Dapper over PostgreSQL. May be Scrutor-decorated with Redis cache.
public interface IListingReadRepository
{
    Task<ListingDetailDto?>             GetDetailAsync(Guid id, CancellationToken ct);
    Task<IReadOnlyList<ListingCardDto>> GetByOwnerAsync(Guid ownerId, int page, CancellationToken ct);
}

// Listing.Application/Listings/IListingSearchRepository.cs — search-shaped reads
// Backed by Elasticsearch. Never PostgreSQL for search.
public interface IListingSearchRepository
{
    Task<ListingSearchPage>     SearchAsync(GeoPolygon area, string? text, int page, CancellationToken ct);
    Task<IReadOnlyList<string>> AutocompleteTitleAsync(string prefix, CancellationToken ct);
}

// Infrastructure layer — one impl class per data store family:
//   Listing.Infrastructure/Persistence/EfListingWriteRepository      : IListingWriteRepository
//   Listing.Infrastructure/Persistence/DapperListingReadRepository   : IListingReadRepository
//   Listing.Infrastructure/Persistence/CachedListingReadRepository   : IListingReadRepository (Scrutor decorator)
//   Listing.Infrastructure/Search/ElasticsearchListingSearchRepository : IListingSearchRepository
```

### Options pattern
```csharp
public class DatabaseOptions
{
    public const string Section = "Database";
    [Required] public string ConnectionString { get; init; } = string.Empty;
    [Range(1, 100)] public int MaxPoolSize { get; init; } = 20;
}

builder.Services.AddOptions<DatabaseOptions>()
    .BindConfiguration(DatabaseOptions.Section)
    .ValidateDataAnnotations()
    .ValidateOnStart();
```

## When to Use
* Implementing or reviewing C# .NET 10 backend code inside a single bounded context
* Designing aggregates, value objects, and domain events for a context
* Writing command/query handlers, validators, and read/write repositories
* Reviewing whether a handler's logic is in the right layer
* Choosing between read-repo and search-repo for a new query

## When NOT to Use
* HTTP endpoint structure, request binding, ProblemDetails mapping, idempotency-key — see `fastendpoints-patterns`
* Cross-context boundaries, integration events, project-per-context structure — see `.specify/memory/system-context.md`
* Outbox publish mechanics, Wolverine consumer topology, Hangfire job conventions — see `wolverine-patterns`
* OTel/Serilog wiring, trace propagation, PII redaction implementation — see `observability-backend`
* Elsa workflow activity definitions — see `workflow-patterns`
* Frontend code (Next.js, React, React Native) — wrong stack
