---
name: messaging-patterns
description: "Load when: designing or implementing async messaging, background jobs, or in-process commands. RabbitMQ + MassTransit topology, MediatR internal dispatch, Hangfire jobs, outbox pattern, saga orchestration."
---

# Messaging, Jobs & Event Patterns

## Purpose
Production patterns for async messaging (RabbitMQ + MassTransit), in-process command/event dispatch (MediatR), and background job scheduling (Hangfire) in .NET 10 services. Covers delivery guarantees, consumer idempotency, saga orchestration, and the transactional outbox.

## Core Rules

### Message Taxonomy

**The word "command" means two different things — never conflate them.**

| Term | Mechanism | Scope | Returns | Purpose |
|---|---|---|---|---|
| **CQRS Command** | MediatR `ICommand` / `ICommand<T>` | In-process, intra-service | `Result` / `Result<TId>` | Mutate an aggregate inside this service (write side of CQRS) |
| **CQRS Query** | MediatR `IQuery<T>` | In-process, intra-service | `Result<TReadModel>` | Read data through a read repository (read side of CQRS) |
| **Integration Command** | MassTransit `IConsumer<T>` over RabbitMQ direct exchange | Cross-service, durable | Void (async with delivery guarantees) | Tell another service to do something |
| **Integration Event** | MassTransit `IConsumer<T>` over RabbitMQ fanout/topic exchange | Cross-service, durable | Void | Announce that something happened in this service |
| **In-process notification** | MediatR `INotification` | In-process, intra-service | Void | Same-process side effects after a command succeeds (not durable) |

**Hard rules:**
* CQRS queries are **never** sent through MassTransit. Reads are always in-process MediatR queries that hit a read repository (PostgreSQL via Dapper / Elasticsearch / Redis cache). Cross-service reads are done through synchronous HTTP (BFF aggregation) or by subscribing to integration events and maintaining a local read model — never request/response over the bus.
* MassTransit commands are not CQRS commands. A MassTransit consumer that receives an integration command typically dispatches a MediatR CQRS command internally to perform the actual aggregate mutation.
* MediatR `INotification` is for same-process side effects only. If the side effect must survive a process crash, publish a MassTransit integration event from the command handler (via the transactional outbox).
* **Naming**:
  * MediatR commands: imperative (`CreateListingCommand`, `ActivateListingCommand`).
  * MediatR queries: question-form (`GetListingDetailQuery`, `SearchListingsByAreaQuery`).
  * MassTransit integration commands: imperative, contract-versioned (`v1.CreateOrderCommand`).
  * MassTransit integration events: past-tense, contract-versioned (`v1.OrderPlaced`, `v1.ListingActivated`).
* **Documents**: data transfer objects passed through messages. Always versioned; include a `SchemaVersion` field.

### Typical Flow Combining All Three

```
HTTP request
  → Controller dispatches MediatR ICommand<Guid> (CQRS write)
      → CommandHandler loads aggregate via IListingWriteRepository,
        mutates aggregate, calls IUnitOfWork.CommitAsync,
        publishes MassTransit integration event via outbox (v1.ListingActivated)
      → CommandHandler returns Result<Guid>
  → Controller returns 201 Created

(asynchronously)
  → MassTransit consumer in Search service receives v1.ListingActivated
      → dispatches local MediatR ICommand to upsert into the Elasticsearch read model
```

The shape of "command" depends on which boundary you are crossing — in-process (MediatR + CQRS) or inter-service (MassTransit + integration contract).

### RabbitMQ Topology (MassTransit)
* Use MassTransit's topology conventions — it creates exchanges and queues automatically. Do not configure RabbitMQ manually unless topology must be shared with non-.NET consumers.
* Exchange per message type (fanout for events, direct for commands).
* Dead-letter exchange configured for every consumer queue. Dead-letter queue depth alert threshold: 1.
* Message TTL: set per-queue based on business SLA. Commands: 24h. Events: 7 days unless domain requires shorter.
* Prefetch count: tune per consumer based on processing time. Default: 16.
* Durable queues and exchanges always. Never transient in production.

### Delivery Guarantee & Idempotency
* Default delivery is **at-least-once**. Every consumer must be idempotent.
* Idempotency strategy per handler — choose one:
  1. **Natural idempotency**: pure computation, no state change, no side effects (document with comment).
  2. **DB unique constraint**: operation naturally deduplicated by a unique constraint (e.g., `UNIQUE(orderId, event_type)`).
  3. **Dedup store**: store processed `MessageId` with TTL ≥ message retention window. Check before executing, store after.
* MassTransit `MessageId` is the dedup key — never generate your own inside the consumer.
* Never rely on exactly-once messaging claims from brokers. Consumers must still be idempotent.

### Transactional Outbox
* Required whenever a consumer or command handler both **writes to the database and publishes an event**.
* Pattern: write state + outbox row in one database transaction; relay process reads outbox and publishes.
* Use MassTransit's Entity Framework outbox (`AddEntityFrameworkOutbox`) for built-in relay.
* Never publish events directly inside a command handler that also writes state — dual-write risk.

### In-Process Messaging (MediatR)
* Use the project's CQRS marker interfaces — `ICommand` / `ICommand<T>` for writes, `IQuery<T>` for reads — defined in `csharp-clean-arch`. Never `IRequest<T>` directly; the markers carry the CQRS intent and let pipeline behaviours target the correct side.
* All return shapes are `Result` / `Result<T>` for fallible operations. Exceptions are reserved for unexpected infrastructure faults and bugs.
* Use `INotification` + `INotificationHandler` for same-process side effects after a successful command. Not durable — lost on process crash; if durability is required, publish a MassTransit integration event from the command handler via the outbox.
* Pipeline behaviours for cross-cutting concerns: validation (`ValidationBehavior` — applies to both commands and queries), logging (`LoggingBehavior`), transaction (`TransactionBehavior` — **command side only**, never wraps a query).

### Sagas (MassTransit StateMachine)
* Use sagas for multi-step business processes with compensation logic.
* State machines (`MassTransitStateMachine<TState>`) are the preferred approach over courier/orchestration for complex workflows without a dedicated workflow engine.
* For SLA-driven workflows with multi-channel notifications, use Elsa v3 instead (see `workflow-patterns`).
* Saga persistence: always use Entity Framework or PostgreSQL saga repository — never in-memory.
* Saga state: name states explicitly; expose current state in observability (`saga_state` metric label).

### Background Jobs (Hangfire)
* Use Hangfire for: scheduled recurring tasks, delayed jobs, fire-and-forget with guaranteed delivery, long-running batch operations.
* Hangfire persistence: PostgreSQL (`Hangfire.PostgreSql`) — same cluster, separate schema `hangfire`.
* Job idempotency: Hangfire retries on failure; every job method must be safe to retry.
* Fire-and-forget: `BackgroundJob.Enqueue(() => ...)` — for operations outside the request cycle.
* Recurring: `RecurringJob.AddOrUpdate(...)` with cron expression — use named jobs for deduplication.
* Do NOT use Hangfire for workflows with SLA enforcement or breach alerts — use Elsa v3.
* Job queue priority: define at least `critical`, `default`, `low` queues. Route time-sensitive jobs to `critical`.
* Hangfire dashboard: secured behind Keycloak auth — admin role only.
* Never pass large payloads to Hangfire jobs. Pass identifiers; the job fetches data itself.

### Error Handling
* Configure retry policies in MassTransit: immediate retry × 3, then interval retry × 5 (exponential backoff), then dead-letter.
* Log at WARN on each retry with attempt count and `MessageId`. Log at ERROR on dead-letter.
* Monitor dead-letter queue depth — alert at threshold 1 for commands, 10 for events.
* Faulted messages in MassTransit produce `Fault<T>` events — subscribe where compensation is needed.

## Patterns / Examples

### MassTransit consumer with idempotency
```csharp
public class ListingActivatedConsumer(IListingSearchIndexer indexer, IDeduplicationStore dedup)
    : IConsumer<ListingActivated>
{
    public async Task Consume(ConsumeContext<ListingActivated> context)
    {
        var msgId = context.MessageId!.Value;
        if (await dedup.HasBeenProcessedAsync(msgId)) return; // idempotency guard

        await indexer.IndexAsync(context.Message.ListingId, context.CancellationToken);
        await dedup.MarkProcessedAsync(msgId, TimeSpan.FromDays(7));
    }
}
```

### Transactional outbox (MassTransit EF Core)
```csharp
// In DbContext configuration
services.AddMassTransit(x =>
{
    x.AddEntityFrameworkOutbox<AppDbContext>(o =>
    {
        o.UsePostgres();
        o.UseBusOutbox(); // relay publishes from outbox table
    });
});

// In command handler — one transaction covers state + outbox
public async Task<Result> Handle(ActivateListingCommand cmd, CancellationToken ct)
{
    await using var tx = await uow.BeginTransactionAsync(ct);
    var listing = await repo.GetByIdAsync(cmd.ListingId, ct);
    listing.Activate();
    await publishEndpoint.Publish(new ListingActivated(listing.Id), ct); // goes to outbox
    await uow.CommitAsync(ct); // commits state + outbox row together
    return Result.Success();
}
```

### MediatR pipeline behaviour (validation)
```csharp
public class ValidationBehavior<TRequest, TResponse>(IEnumerable<IValidator<TRequest>> validators)
    : IPipelineBehavior<TRequest, TResponse> where TRequest : IRequest<TResponse>
{
    public async Task<TResponse> Handle(TRequest request, RequestHandlerDelegate<TResponse> next, CancellationToken ct)
    {
        var failures = validators
            .Select(v => v.Validate(request))
            .SelectMany(r => r.Errors)
            .Where(e => e is not null)
            .ToList();

        if (failures.Count != 0) throw new ValidationException(failures);
        return await next();
    }
}
```

### Recurring Hangfire job
```csharp
// Registration
RecurringJob.AddOrUpdate<IListingExpiryJob>(
    "listing-expiry-check",
    job => job.ExecuteAsync(CancellationToken.None),
    Cron.Daily(hour: 2),
    new RecurringJobOptions { TimeZone = TimeZoneInfo.Utc });

// Job implementation — always idempotent
public class ListingExpiryJob(IListingRepository repo, ISender mediator, ILogger<ListingExpiryJob> logger)
    : IListingExpiryJob
{
    public async Task ExecuteAsync(CancellationToken ct)
    {
        var expired = await repo.GetExpiredActiveListingsAsync(DateTimeOffset.UtcNow, ct);
        logger.LogInformation("Expiring {Count} listings", expired.Count);
        foreach (var id in expired.Select(l => l.Id))
            await mediator.Send(new ExpireListingCommand(id), ct);
    }
}
```

## When to Use
* Designing inter-service event flows
* Implementing MassTransit consumers, sagas, or producers
* Adding Hangfire recurring or deferred jobs
* Any handler that both writes state and needs to trigger downstream effects

## When NOT to Use
* SLA enforcement, multi-step workflows with breach alerts → use `workflow-patterns` (Elsa v3)
* In-memory pub/sub for simple UI event broadcasting (SignalR)
* Synchronous request/response between services → use BFF aggregation or gRPC
