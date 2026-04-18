---
name: messaging-patterns
description: "Load when: designing or implementing async messaging, background jobs, or in-process commands. RabbitMQ + MassTransit topology, MediatR internal dispatch, Hangfire jobs, outbox pattern, saga orchestration. Loaded by: sk.architecture, sk.plan, sk.implement (backend)."
---

# Messaging, Jobs & Event Patterns

## Purpose
Production patterns for async messaging (RabbitMQ + MassTransit), in-process command/event dispatch (MediatR), and background job scheduling (Hangfire) in .NET 10 services. Covers delivery guarantees, consumer idempotency, saga orchestration, and the transactional outbox.

## Core Rules

### Message Taxonomy
* **Commands** (MassTransit): requests directed at one recipient that must happen. Named imperatively: `PlaceOrder`, `ActivateListing`. Delivered to a single consumer.
* **Events** (MassTransit): notifications that something occurred. Named past-tense: `OrderPlaced`, `ListingActivated`. Delivered to all interested consumers via fanout/topic exchange.
* **In-process notifications** (MediatR `INotification`): same-process side effects after a command succeeds. Not durable — use only for same-transaction side effects.
* **Documents**: data transfer objects passed through messages. Always versioned; include a `SchemaVersion` field.

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
* Use `INotification` + `INotificationHandler` for same-process side effects after a successful domain operation.
* MediatR notifications are not durable — they are lost on process crash. If durability is required, publish via MassTransit instead.
* Use `IRequest<Result<T>>` for commands and queries — never `IRequest<T>` for fallible operations.
* Pipeline behaviours for cross-cutting concerns: validation (`ValidationBehavior`), logging (`LoggingBehavior`), transaction (`TransactionBehavior`).

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
