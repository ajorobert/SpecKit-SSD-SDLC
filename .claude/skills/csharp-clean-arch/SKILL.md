---
name: csharp-clean-arch
description: "Load when: implementing or reviewing C# .NET 10 backend services. Clean Architecture layer rules, DI, async, EF Core, Dapper, Result pattern, xUnit+Moq testing. Loaded by: sk.implement (backend), sk.review (backend), sk.plan."
---

# C# Clean Architecture (.NET 10)

## Purpose
Production patterns for C# ASP.NET Core 10 services using Clean Architecture with bounded context project structure. Enforces layer separation, dependency rules, async correctness, and testability for directory service backends.

## Core Rules

### Layer Boundaries
* **Domain**: Entities, value objects, domain events, aggregate roots, repository interfaces, domain services. Zero infrastructure or framework dependencies. Never reference EF Core, MassTransit, or any library.
* **Application**: Use cases (commands/queries via MediatR), application services, DTOs, validators (FluentValidation), and interface definitions for external services. No direct DB access — only through repository interfaces from Domain.
* **Infrastructure**: EF Core `DbContext`, repository implementations, MassTransit consumers, Redis clients, Elasticsearch clients, Elsa workflow activities, HTTP clients for external services. Implements interfaces declared in Domain/Application.
* **API**: Controllers, middleware, request/response models, DI wiring. No business logic, no domain construction, no DB calls.
* One bounded context = one project/solution. Never share domain entities across service boundaries — use integration events and anti-corruption layers.
* Namespace convention: `{ServiceName}.{Layer}.{Feature}` (e.g., `ListingService.Application.Listings`).

### Dependency Injection (.NET 10)
* Use primary constructor syntax — the idiomatic .NET 10 pattern:
  ```csharp
  public class OrderService(IOrderRepository repo, ILogger<OrderService> logger) { }
  ```
* Register per layer via extension methods: `services.AddDomain()`, `services.AddApplication()`, `services.AddInfrastructure(config)`, `services.AddApi()`.
* Lifetimes: Scoped for DbContext and repositories; Singleton for thread-safe stateless services; Transient for lightweight non-shared utilities.
* Never use `new` to instantiate services. Never use service locator pattern.
* Use `IOptions<T>` with `ValidateDataAnnotations()` and `ValidateOnStart()` for all configuration.

### Async Patterns (.NET 10)
* Async all the way — never block an async call chain.
* Always accept and forward `CancellationToken` from controller down to repository.
* Use `Task.WhenAll` for independent parallel I/O operations.
* No `Task.Run` for I/O work — it wastes thread pool threads. Only for genuinely CPU-bound offloading.
* Do NOT use `ConfigureAwait(false)` in application/API code. Only library authors need it.
* Never use `.Result`, `.Wait()`, or `.GetAwaiter().GetResult()` — deadlocks in ASP.NET context.
* Never use `async void` except for event handlers (unavoidable).
* Use `ValueTask<T>` for hot-path operations that frequently complete synchronously.

### Controllers
* Controllers: validate input → dispatch to MediatR → return response. Nothing else. Max 15 lines per action.
* No business logic. No domain object construction. No direct service calls that contain logic.
* Use `[ApiController]` for automatic model state validation.
* Return typed `ActionResult<T>` — never `object`.
* Use problem details (`ProblemDetails`) for error responses. Map Result errors to HTTP status codes in a response mapper, not in controller actions.

### Result Pattern
* All application handlers return `Result<T>` or `Result` for operations that can fail in expected ways.
* Use exceptions only for unexpected infrastructure failures or programming errors (bugs).
* Never throw domain exceptions across service boundaries — translate to Result or integration events.
* Provide explicit error types: `NotFoundError`, `ValidationError`, `ConflictError`, `UnauthorizedError`.

### CQRS — Mandatory Separation of Reads and Writes

This solution enforces CQRS at the Application layer. Every use case is either a **command** (changes state, returns `Result` or `Result<TId>`) or a **query** (reads data, returns `Result<TReadModel>`). They never share handlers, never share repositories, and never share the same data path.

**Marker interfaces** (defined in Application):
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

**Write side** (commands):
* Loads aggregate roots through `I{Aggregate}WriteRepository` — methods return rich domain entities, never DTOs.
* Mutates aggregates by invoking domain methods (`listing.Activate()`), never by setting properties.
* Persists through EF Core via Unit of Work; emits domain events that become integration events via the transactional outbox (see `messaging-patterns`).
* Write repositories expose: `GetByIdAsync`, `AddAsync`, `UpdateAsync`. Never list/search/projection methods.

**Read side** (queries):
* Routes to a **separate** `I{Entity}ReadRepository` or `I{Entity}Queries` interface returning DTOs / read models.
* Implementation chooses the appropriate read store per access pattern:
  | Access pattern | Read store |
  |---|---|
  | Single entity by ID, hot read | Redis cache → fall through to PostgreSQL |
  | Listing search, geo, faceted | Elasticsearch (mandatory — never PostgreSQL) |
  | Reporting, paged lists, joins for projection | Dapper over PostgreSQL replica |
  | Latest entity state with no caching needed | EF Core `.AsNoTracking()` |
* Read repositories return DTOs/records — never aggregate roots, never `IQueryable`.
* Read models are decoupled from domain entities — they are reshaped for the consumer.

**Hard rules:**
* A handler that writes must not return read DTOs. Return `Result<Guid>` (new ID) or `Result` (no payload). Clients re-fetch via the query side.
* A read repository must not be injected into a command handler. A write repository must not be injected into a query handler.
* The same physical table may back both — the *interfaces* and the *handlers* are split. CQRS here is logical, not necessarily physical separation of databases.

### Data Access
* EF Core for transactional writes through aggregate roots — the only write path.
* Dapper over PostgreSQL (or replica) for performance-critical read projections and reporting queries — read side only.
* Elasticsearch for search-shaped reads (geo, full-text, faceted) — read side only.
* Redis cache-aside for hot single-entity reads — read side only, never on the write path.
* Always use `.AsNoTracking()` for any EF Core query in a query handler.
* Apply global query filters for soft deletes (`IsDeleted`) and multi-tenancy (`TenantId`).
* Repositories expose domain-semantic methods (`GetActiveListingsForAreaAsync`), not `IQueryable`.
* Use the Unit of Work pattern on the **write side only** for transaction coordination across multiple write repositories.

### Error Handling & Logging
* Structured logging via `Microsoft.Extensions.Logging` with JSON output. No unstructured plain text in production.
* Required log fields: `service`, `trace_id`, `span_id`, entity IDs relevant to the operation, `level`, `message`.
* WARN for expected degraded states (retry, cache miss, fallback). ERROR for unexpected failures.
* Never log passwords, tokens, PII, or payment data.
* Global exception handling middleware catches unhandled exceptions — services should not swallow them silently.

### Testing
* xUnit for test runner. Moq for mocking dependencies.
* AAA pattern strictly (Arrange / Act / Assert).
* `WebApplicationFactory<TProgram>` for integration tests against real PostgreSQL (no mocked DB).
* Unit test: domain logic, application command/query handlers, validators, domain services.
* Integration test: repository implementations, API endpoints, event consumers.
* Coverage minimums: Domain 95%, Application 90%, API endpoints 80%.
* Use `[Theory]` with `[InlineData]` for boundary and equivalence class testing.

### Code Quality
* Max 30 lines per method. Extract when exceeded.
* Max 3 parameters per method — use a command/query object or parameter object beyond that.
* SOLID: single responsibility enforced by layer structure; open/closed via extension points; LSP/ISP via focused interfaces; DIP via constructor injection.
* Use `record` types for immutable DTOs, value objects, and commands/queries.
* No static mutable state in services. No ambient context patterns.
* Public method names: verb-noun describing intent (`CreateListing`, `GetActiveAreaListings`).

## Patterns / Examples

### Command + Handler (write side)
```csharp
// Application layer
public record CreateListingCommand(Guid OwnerId, string Title, decimal Price, GeoPoint Location)
    : ICommand<Guid>;

public class CreateListingHandler(
    IListingWriteRepository repo,
    IUnitOfWork uow,
    ILogger<CreateListingHandler> logger)
    : ICommandHandler<CreateListingCommand, Guid>
{
    public async Task<Result<Guid>> Handle(CreateListingCommand cmd, CancellationToken ct)
    {
        var listing = Listing.Create(cmd.OwnerId, cmd.Title, cmd.Price, cmd.Location);
        await repo.AddAsync(listing, ct);
        await uow.CommitAsync(ct);
        logger.LogInformation("Listing {ListingId} created by owner {OwnerId}", listing.Id, cmd.OwnerId);
        return Result.Success(listing.Id);
    }
}
```

### Query + Handler (read side)
```csharp
// Application layer — returns a DTO, never an aggregate
public record GetListingDetailQuery(Guid ListingId) : IQuery<ListingDetailDto>;

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
```

### Repository Interfaces — Split by Side (Domain / Application layer)
```csharp
// Domain layer — write side, aggregate-oriented, no EF Core reference
public interface IListingWriteRepository
{
    Task<Listing?> GetByIdAsync(Guid id, CancellationToken ct);   // load aggregate for mutation
    Task AddAsync(Listing listing, CancellationToken ct);
    Task UpdateAsync(Listing listing, CancellationToken ct);
}

// Application layer — read side, DTO-oriented, infrastructure picks the data store
public interface IListingReadRepository
{
    Task<ListingDetailDto?>           GetDetailAsync(Guid id, CancellationToken ct);
    Task<IReadOnlyList<ListingCardDto>> GetActiveInAreaAsync(GeoPolygon area, CancellationToken ct);
}

// Infrastructure layer — implementations may pick different stores per method
// e.g. GetDetailAsync → Redis cache + Dapper fallback
//      GetActiveInAreaAsync → Elasticsearch geo query
```

### Controller (API layer)
```csharp
[ApiController]
[Route("api/v1/listings")]
[Authorize]
public class ListingsController(ISender mediator) : ControllerBase
{
    [HttpPost]
    [ProducesResponseType<Guid>(StatusCodes.Status201Created)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<Guid>> Create(CreateListingRequest request, CancellationToken ct)
    {
        var result = await mediator.Send(request.ToCommand(User.GetOwnerId()), ct);
        return result.Match(
            id => CreatedAtAction(nameof(GetById), new { id }, id),
            error => this.Problem(error));
    }
}
```

### Options Pattern
```csharp
public class DatabaseOptions
{
    public const string Section = "Database";

    [Required] public string ConnectionString { get; init; } = string.Empty;
    [Range(1, 100)] public int MaxPoolSize { get; init; } = 20;
}

// In Program.cs
builder.Services.AddOptions<DatabaseOptions>()
    .BindConfiguration(DatabaseOptions.Section)
    .ValidateDataAnnotations()
    .ValidateOnStart();
```

## When to Use
* Any C# .NET 10 backend service implementation or review
* Designing a new bounded context service
* Adding features or refactoring existing backend code
* Planning the project structure for a new service

## When NOT to Use
* Frontend code (Next.js, React, React Native)
* Infrastructure scripts or deployment tooling
* Elsa workflow activity definitions (see `workflow-patterns`)
* MassTransit consumer topology (see `messaging-patterns`)
