---
name: design-code-review
description: "Load when: reviewing C# .NET 10 backend code. Design pattern compliance, SOLID, architecture conventions, async correctness, security, performance, testability."
---

# .NET Design Pattern Review

## Purpose
Structured review checklist for C# .NET 10 backend code. Evaluates design pattern correctness, SOLID compliance, architecture layer adherence, async safety, security, and testability. Read-only — produces findings, does not modify code.

## Core Rules

### Review Dimensions (evaluate all seven)

**1. Layer Architecture**
* Domain layer has zero infrastructure dependencies (no EF Core, no MassTransit, no HttpClient).
* Application layer depends only on Domain interfaces — no direct DB access, no infrastructure calls.
* Infrastructure implements interfaces from Domain/Application — never the reverse.
* Controllers contain no business logic. Actions: validate → dispatch → respond.
* Namespace follows `{ServiceName}.{Layer}.{Feature}` convention.

**2. Design Patterns**
* Command/Query handlers use `IRequest<Result<T>>` via MediatR — one handler per use case.
* Repository pattern: domain-semantic method names, not `IQueryable` exposure.
* Factory pattern for complex aggregate construction — validates invariants before returning.
* Provider/adapter pattern for external service integration — concrete implementations in Infrastructure only.
* Result pattern used for expected failures — exceptions not used for control flow.

**3. SOLID Compliance**
* Single Responsibility: each class has one reason to change. Flag classes doing more than one concern.
* Open/Closed: extension via new classes (new handlers, new strategies) not modifying existing ones.
* Liskov Substitution: subtypes honour base type contracts fully.
* Interface Segregation: interfaces are narrow and focused. Flag interfaces with 5+ methods.
* Dependency Inversion: high-level modules depend on abstractions, not concrete types.

**4. Async Correctness (.NET 10)**
* No `.Result`, `.Wait()`, `.GetAwaiter().GetResult()` — deadlock risk.
* No `async void` (except unavoidable event handlers).
* No `Task.Run` wrapping I/O work.
* `CancellationToken` accepted and forwarded in all async methods.
* No unnecessary `ConfigureAwait(false)` in application code.

**5. Security**
* No credentials, connection strings, or secrets hardcoded.
* All user input validated before processing (FluentValidation in Application layer).
* Parameterised queries only — no string concatenation in SQL.
* No sensitive data (passwords, tokens, PII) in log output.
* Authorization checked before any domain operation — not only at route level.

**6. CQRS Compliance**
* Every use case is implemented as either a **command** (`ICommand` / `ICommand<T>`) or a **query** (`IQuery<T>`) — never a generic `IRequest`.
* Command handlers (`ICommandHandler<...>`) inject only **write** repositories (`I{Aggregate}WriteRepository`) and `IUnitOfWork`. They mutate aggregate roots through domain methods and return `Result` or `Result<TId>` only — never read DTOs.
* Query handlers (`IQueryHandler<...>`) inject only **read** repositories (`I{Entity}ReadRepository` / `I{Entity}Queries`). They return DTOs / read models — never aggregate roots, never `IQueryable`.
* No handler injects both a write repository and a read repository. No repository interface exposes both write methods (`AddAsync`, `UpdateAsync`) and projection methods (`GetXxxDtoAsync`).
* Search-shaped queries (geo, full-text, faceted) route to Elasticsearch — never direct PostgreSQL queries from a search query handler.
* Cache-aside lookups live on the read side only — either as a `Cached{Entity}ReadRepository` decorator or inside a query handler. Never inside a command handler.
* After a command, clients re-fetch via the query side. Commands do not return read DTOs as a "convenience".

**7. Testability**
* All dependencies injected via constructor — no `new` for services, no static calls.
* No static mutable state.
* Methods are deterministic and side-effect free where possible.
* Handlers can be unit tested by mocking repository and external service interfaces.

### Blocking Issues (must fix before ship)
* Domain layer referencing infrastructure libraries.
* Business logic in controllers.
* `.Result` / `.Wait()` blocking calls in async context.
* Hardcoded secrets or connection strings.
* Missing input validation on public-facing endpoints.
* `IQueryable` exposed from repository interfaces.
* CQRS violations: a single repository interface exposing both write methods and projection/list/search methods; a command handler returning a read DTO; a query handler invoking write methods or `IUnitOfWork.CommitAsync`; a search query bypassing Elasticsearch and going directly to PostgreSQL; an Infrastructure read-repository implementation that targets more than one data store family (e.g. one class doing both Dapper and Elasticsearch calls) — split into `I{Entity}ReadRepository` (PostgreSQL) and `I{Entity}SearchRepository` (Elasticsearch) per `csharp-clean-arch`.

### Advisory Issues (flag and recommend)
* Methods exceeding 30 lines — extract to private methods or separate class.
* More than 3 constructor parameters — consider grouping related dependencies.
* Missing XML documentation on public domain interfaces and DTOs.
* Missing cancellation token propagation.
* `catch (Exception)` without re-throw or structured logging.

## Patterns / Examples

### Correct: Command handler
```csharp
// ✅ Single responsibility, Result return, injected deps, CancellationToken
public class DeactivateListingHandler(IListingRepository repo, IUnitOfWork uow)
    : IRequestHandler<DeactivateListingCommand, Result>
{
    public async Task<Result> Handle(DeactivateListingCommand cmd, CancellationToken ct)
    {
        var listing = await repo.GetByIdAsync(cmd.ListingId, ct);
        if (listing is null) return Result.Failure(new NotFoundError("Listing not found"));
        listing.Deactivate();
        await uow.CommitAsync(ct);
        return Result.Success();
    }
}
```

### Incorrect: Business logic in controller
```csharp
// ❌ Controller doing domain work
[HttpDelete("{id}")]
public async Task<IActionResult> Delete(Guid id)
{
    var listing = await _db.Listings.FindAsync(id); // direct DB access
    if (listing.OwnerId != User.GetId()) return Forbid(); // auth logic here
    listing.IsActive = false; // domain mutation
    await _db.SaveChangesAsync();
    return NoContent();
}
```

### Correct: Repository interface
```csharp
// ✅ Domain-semantic, no IQueryable leak
public interface IListingRepository
{
    Task<Listing?> GetByIdAsync(Guid id, CancellationToken ct);
    Task<IReadOnlyList<Listing>> GetActiveInAreaAsync(GeoPolygon area, CancellationToken ct);
    Task AddAsync(Listing listing, CancellationToken ct);
}

// ❌ Leaks EF Core and query composition to callers
public interface IListingRepository
{
    IQueryable<Listing> Query();
}
```

## When to Use
* Any backend C# code review for design pattern or SOLID compliance
* Pre-merge review of pull requests touching Application, Domain, or Infrastructure layers
* Architecture audit of an existing service

## When NOT to Use
* Frontend code review (see `react-component-patterns`, `nextjs-patterns`)
* Infrastructure scripts or Terraform/Bicep review
* Database migration review (see `postgresql-patterns`)
