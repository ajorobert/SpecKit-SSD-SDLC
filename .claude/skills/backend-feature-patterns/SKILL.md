---
name: backend-feature-patterns
description: |
  Backend feature implementation pattern for .NET 10 Clean Architecture with Wolverine, ErrorOr, Mapster, FluentValidation. Covers layer boundaries, command/query handler shape, response contract, validation pipeline, idempotency, Mapster mapping, comment-markers index. Use for every backend feature that touches business logic.
when_to_load:
  - Task mentions: feature, handler, command, query, application layer, domain, mapping, validation, idempotency
  - Files touched: any *Handler.cs, *Command.cs, *Query.cs, *Validator.cs, *MappingConfig.cs, aggregate roots
co_loads_with:
  - wolverine-patterns (handler dispatch + outbox)
  - fastendpoints-patterns (HTTP entry to handlers)
  - persistence-patterns (EF write + Dapper read inside handlers)
  - hybridcache-patterns (cache-aside in query handlers)
---

# Backend Feature Patterns

## 1. Layer model

```
Domain ← Application ← Infrastructure ← Api
  (arrow = "knows about" / depends on)
```

| Layer | Knows | Depends on |
|---|---|---|
| Domain | Aggregates, value objects, domain events, port interfaces | nothing (compiles with `Microsoft.NET.Sdk` only) |
| Application | Use cases (commands/queries), handlers, validators, mapping configs, port interfaces | Domain |
| Infrastructure | EF write repos, Dapper read services, port adapters, Wolverine handlers' infra needs | Domain + Application |
| Api | FastEndpoints, request/response DTOs, ErrorOr→HTTP mapping | Domain + Application (resolves Infrastructure at runtime) |

**Ban table.** Domain ⇏ Application/Infrastructure/Api. Application ⇏ Infrastructure/Api. Infrastructure ⇏ Api. Api references all.

Project layout uses `YourContext.<Layer>` naming — `YourContext.Domain`, `YourContext.Application`, `YourContext.Infrastructure`, `YourContext.Api`. Project structure rules live in `.specify/memory/system-context.md`.

## 2. Domain rules

- Aggregate root: private setters, factory method, invariants checked in constructor or factory.
- Domain events: `record` types in the same folder as the aggregate.
- Allowed dependencies inside Domain: nothing concrete. Only port interfaces declared in Domain itself (e.g. `IClock`, `IIdGenerator`) — implementations live in Infrastructure.
- **Do NOT inject** `DbContext`, `IMessageBus`, `IConnectionMultiplexer`, `IDatabase`, `IDistributedCache`, `HttpClient`, `IConfiguration`, framework logger types into entities or domain services. Use a port OR keep the operation in the Application layer.

```csharp
namespace YourContext.Domain.Listings;

public sealed class Listing : AggregateRoot
{
    public ListingId Id { get; }
    public OwnerId OwnerId { get; }
    public ListingStatus Status { get; private set; }
    public Money Price { get; private set; }

    private Listing(ListingId id, OwnerId owner, Money price)
    { Id = id; OwnerId = owner; Price = price; Status = ListingStatus.Draft; }

    public static ErrorOr<Listing> Create(OwnerId owner, Money price)
    {
        if (price.Amount <= 0) return Error.Validation("Listing.PriceInvalid", "Price must be > 0");
        var l = new Listing(ListingId.New(), owner, price);
        l.RaiseEvent(new ListingCreatedEvent(l.Id, owner));
        return l;
    }

    public ErrorOr<Success> Activate()
    {
        if (Status != ListingStatus.Draft)
            return Error.Conflict("Listing.AlreadyActive", "Listing is already active");
        Status = ListingStatus.Active;
        RaiseEvent(new ListingActivatedEvent(Id));
        return Result.Success;
    }
}
```

## 3. Application layer: command shape

File layout per use case:

```
YourContext.Application/Features/<Aggregate>/<UseCase>/
  Command.cs        // record
  Handler.cs        // plain Wolverine handler — see wolverine-patterns §2
  Validator.cs      // : AbstractValidator<Command>
  MappingConfig.cs  // optional Mapster IRegister
```

Rules:

- Command is a `record` with primary constructor — immutable, no behaviour.
- Handler is a plain class with a `Handle` method discovered by Wolverine convention.
- Return type is `ErrorOr<TResponse>` — **never throw for business failures**. Throw only for programmer errors and impossible states.
- Handler MAY inject `IMessageBus` / `IMessageContext`, port interfaces, `HybridCache`, write/read repositories, `IMapper`.
- Handler MUST NOT inject `DbContext` directly — go through a write repository interface.
- Handler MUST NOT catch exceptions to convert them to errors — Wolverine middleware handles unexpected exceptions.
- Handler MUST NOT call `bus.PublishAsync` outside an outbox-bound path — use `IMessageContext.EnqueueAsync` inside `[Transactional]` (see `wolverine-patterns` §4).

```csharp
namespace YourContext.Application.Features.Listings.Activate;

public sealed record ActivateListingCommand(Guid ListingId, Guid ActorId, string? IdempotencyKey = null);

[Transactional]
public sealed class ActivateListingHandler(IListingWriteRepository repo, IClock clock)
{
    public async Task<ErrorOr<Success>> Handle(ActivateListingCommand cmd, IMessageContext bus, CancellationToken ct)
    {
        var listing = await repo.GetByIdAsync(new ListingId(cmd.ListingId), ct);
        if (listing is null) return Error.NotFound("Listing.NotFound", "Listing not found");

        var activated = listing.Activate();
        if (activated.IsError) return activated.Errors;

        await bus.EnqueueAsync(new ListingActivatedIntegrationEvent(listing.Id, clock.UtcNow));
        await repo.SaveChangesAsync(ct);
        return Result.Success;
    }
}

public sealed class ActivateListingValidator : AbstractValidator<ActivateListingCommand>
{
    public ActivateListingValidator() => RuleFor(x => x.ListingId).NotEmpty();
}
```

## 4. Application layer: query shape

Query handlers read through a read service (Dapper-backed — see `persistence-patterns`). Cache-wrap reads with `HybridCache.GetOrCreateAsync` (see `hybridcache-patterns` §4).

```csharp
namespace YourContext.Application.Features.Listings.GetDetail;

public sealed record GetListingDetailQuery(Guid ListingId);

public sealed class GetListingDetailHandler(HybridCache cache, IListingReadService reads)
{
    private static readonly HybridCacheEntryOptions Options = new()
    {
        Expiration           = TimeSpan.FromMinutes(5),
        LocalCacheExpiration = TimeSpan.FromMinutes(1),
    };

    public async Task<ErrorOr<ListingDetailDto>> Handle(GetListingDetailQuery q, CancellationToken ct)
    {
        // CACHE-TAG: yourcontext:listing — bulk-invalidated on any listing write
        var dto = await cache.GetOrCreateAsync(
            $"yourcontext:listing:{q.ListingId}:detail",
            token => reads.GetDetailAsync(q.ListingId, token).AsTask(),
            Options,
            tags: ["yourcontext:listing"],
            cancellationToken: ct);

        return dto is null ? Error.NotFound("Listing.NotFound", "Listing not found") : dto;
    }
}
```

## 5. ErrorOr contract

`ErrorOr<T>` is the only return shape for handlers. Use exceptions only for programmer errors and impossible states. The five error types you actually use:

| Type | Use for | HTTP (mapping in fastendpoints-patterns §7) |
|---|---|---|
| `Error.Validation(code, desc)` | Input shape, ranges, format | 400 |
| `Error.NotFound(code, desc)` | Identifier resolves to nothing | 404 |
| `Error.Conflict(code, desc)` | State-machine refusal, optimistic-concurrency clash | 409 |
| `Error.Forbidden(code, desc)` | Authenticated caller lacks the right | 403 |
| `Error.Failure(code, desc)` | Genuine infra/unexpected, but caught | 500 |

Code/description convention: `<Aggregate>.<Symbol>` for the code; human-readable, ASCII-only for the description. Examples — `Listing.AlreadyActive`, `Order.OutOfStock`, `Payment.Declined`.

Where errors are constructed:

- **In the aggregate** (factories and state-mutating methods): prefer returning `ErrorOr<TAggregate>` / `ErrorOr<Success>` over `throw`. Domain invariants surface as `Error.Conflict` or `Error.Validation`.
- **In the handler**: thread aggregate results with LINQ-style combinators (`.Then`, `.ThenAsync`, `.Match`) instead of imperative `if (result.IsError) return …` ladders when the chain is more than two steps.

```csharp
public async Task<ErrorOr<Guid>> Handle(CreateListingCommand cmd, CancellationToken ct)
{
    var money = Money.Create(cmd.Amount, cmd.Currency);                  // ErrorOr<Money>
    return await money
        .Then(m => Listing.Create(new OwnerId(cmd.OwnerId), m))           // ErrorOr<Listing>
        .ThenAsync(async listing =>
        {
            await repo.AddAsync(listing, ct);
            await repo.SaveChangesAsync(ct);
            return listing.Id.Value;
        });
}
```

## 6. FluentValidation

The validator class lives next to the command in the same feature folder. Wolverine middleware auto-discovers validators by assembly scan and runs them **before** the handler — validation failures short-circuit and surface as `Error.Validation` to the endpoint; the handler does not need to call the validator manually.

Split rules by intent:

- **Per-property** rules (`NotEmpty`, `MaximumLength`, `Matches`) go inline on `RuleFor(x => x.Field)`.
- **Cross-field** rules (`MustAsync`, `When`/`Unless` combinations) go on the command as a whole — usually one `RuleFor(x => x)` with a custom validator.

```csharp
public sealed class CreateBookingValidator : AbstractValidator<CreateBookingCommand>
{
    public CreateBookingValidator()
    {
        RuleFor(x => x.StartsAt).NotEmpty();
        RuleFor(x => x.EndsAt).NotEmpty();
        RuleFor(x => x).Must(c => c.EndsAt > c.StartsAt)
            .WithMessage("EndsAt must be after StartsAt")
            .WithErrorCode("Booking.RangeInvalid");
    }
}
```

## 7. Mapster

Mapping configs live in `YourContext.Application/Features/<Aggregate>/Mappings/` as `IRegister` implementations. Source-gen is enabled (AOT-friendly). Handlers and endpoints inject `IMapper` — never call static `Adapt<T>()` from handlers (untestable).

```csharp
namespace YourContext.Application.Features.Listings.Mappings;

public sealed class ListingMappingConfig : IRegister
{
    // MAP: Listing → ListingDetailDto — flattens Owner + Price for the read DTO
    public void Register(TypeAdapterConfig config) =>
        config.NewConfig<Listing, ListingDetailDto>()
              .Map(d => d.OwnerId, s => s.OwnerId.Value)
              .Map(d => d.Price,   s => s.Price.Amount)
              .Map(d => d.Currency, s => s.Price.Currency);
}

// Inside a handler:
public async Task<ErrorOr<ListingDetailDto>> Handle(GetListingDetailQuery q, CancellationToken ct)
{
    var listing = await repo.GetByIdAsync(new ListingId(q.ListingId), ct);
    return listing is null
        ? Error.NotFound("Listing.NotFound")
        : mapper.Map<ListingDetailDto>(listing);
}
```

## 8. Idempotency contract

Two layers, both required:

1. **Wolverine inbox** dedupes brokered messages by envelope id — automatic, see `wolverine-patterns` §2.
2. **HTTP idempotency-key** dedupes user-initiated retries. The endpoint reads `Idempotency-Key` header and forwards it on the command as `IdempotencyKey` (see `fastendpoints-patterns` §6 for the HTTP-side contract).

When the operation is sensitive (charges money, triggers external notifications), the handler treats `IdempotencyKey` as part of the dedup tuple — check the store before mutating; record the response under the key after success.

```csharp
public async Task<ErrorOr<OrderPlacedResponse>> Handle(PlaceOrderCommand cmd, CancellationToken ct)
{
    if (cmd.IdempotencyKey is null) return Error.Validation("Order.IdempotencyKeyRequired");

    // IDEMPOTENCY: replay protection on (idempotencyKey, fingerprint)
    var replay = await idempotency.TryReplayAsync<OrderPlacedResponse>(cmd.IdempotencyKey, cmd, ct);
    if (replay is not null) return replay;

    var order = Order.Place(cmd.CustomerId, cmd.Items);
    if (order.IsError) return order.Errors;
    await repo.AddAsync(order.Value, ct);
    await repo.SaveChangesAsync(ct);

    var response = new OrderPlacedResponse(order.Value.Id.Value);
    await idempotency.RecordAsync(cmd.IdempotencyKey, cmd, response, ct);
    return response;
}
```

## 9. Repositories

This skill states the boundary; `persistence-patterns` owns the implementation details.

- **Write repository per aggregate** — interface in Application, EF Core implementation in Infrastructure. Methods: `GetByIdAsync`, `AddAsync`, `RemoveAsync`, `SaveChangesAsync`. Transactional unit-of-work via Wolverine `[Transactional]` (see `wolverine-patterns` §4) — the handler does not own `BeginTransaction`/`Commit`.
- **Read service per query family** — interface in Application, Dapper implementation in Infrastructure (see `persistence-patterns`).
- **No generic `IRepository<T>`** — it loses Include/projection composition and pushes leaks into call sites. Each aggregate gets its own typed repository.

```csharp
namespace YourContext.Application.Features.Listings;

public interface IListingWriteRepository
{
    Task<Listing?> GetByIdAsync(ListingId id, CancellationToken ct);
    Task AddAsync(Listing listing, CancellationToken ct);
    Task RemoveAsync(Listing listing, CancellationToken ct);
    Task SaveChangesAsync(CancellationToken ct);
}
```

## 10. Comment markers index (canonical home)

| Marker | Owner skill | Annotates |
|---|---|---|
| `// AUTH:` | fastendpoints-patterns | Endpoint authorization policy/role |
| `// ENDPOINT:` | fastendpoints-patterns | Endpoint route + verb |
| `// OUTBOX:` | wolverine-patterns | Outbox-bound publish |
| `// SAGA-STATE:` | wolverine-patterns | Saga state field |
| `// CACHE-TAG:` | hybridcache-patterns | Cache tag(s) for entry |
| `// CACHE-INVALIDATE:` | hybridcache-patterns | Cache invalidation call |
| `// MAP:` | backend-feature-patterns | Mapster custom mapping entry |
| `// IDEMPOTENCY:` | backend-feature-patterns | HTTP idempotency dedup check |
| `// CONFIGUREAWAIT:` | this skill | Library/adapter code line where `ConfigureAwait(false)` is required |
| `// COLOR:` | frontend-design-system | Escape hatch for non-token color |

Markers are CI-greppable. Each owner skill is responsible for emitting and documenting its own markers; this table is the single source of truth for the cross-skill set.

**`// CONFIGUREAWAIT:` rule.** Handlers omit `ConfigureAwait(false)` — Wolverine controls the synchronization context. Library/adapter code (anything in `YourContext.Infrastructure/Ports/` or shared utility libraries) uses `ConfigureAwait(false)` and marks the call site once near the top of the file.

## 11. Anti-patterns

- Generic `IRepository<T>` — typed repositories per aggregate only.
- `static class` for business logic — handlers and domain methods own behaviour.
- Anemic domain model — logic in handlers/services that should be on the aggregate.
- Throwing for business failures — return `ErrorOr<T>` instead.
- `async void` — never, except for event handlers (and we don't have those here).
- Multiple commands in one handler — one operation per handler.
- `IMapper` injected into entities — mapping is an Application/Api concern only.
- `if (entity.Status == X)` branches inside handlers — that's a domain invariant; move it onto the aggregate.

## 12. Testing

Unit-test handlers in isolation using Wolverine's test harness (`AlbaHost` + `IMessageBus`) — see `wolverine-patterns` §10 for the host shape. Validators are tested separately via `FluentValidation.TestHelper` (`.TestValidate(command)` + `.ShouldHaveValidationErrorFor(...)`). Mapping configs are not unit-tested in isolation; they are covered by the integration tests of the handlers that use them.

## 13. References

- `wolverine-patterns` — handler dispatch shape, outbox publish rule, sagas, scheduled messages.
- `fastendpoints-patterns` — HTTP entry, ErrorOr-to-HTTP mapping, idempotency-key header.
- `persistence-patterns` — EF write repositories, Dapper read services.
- `hybridcache-patterns` — cache-aside in query handlers, invalidation.
- `.specify/memory/system-context.md` — project-specific layer naming.
