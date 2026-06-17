---
name: workflow-and-jobs-patterns
description: |
  Long-running workflows (Elsa v3) and in-process background jobs (Hangfire) for .NET 10. Covers the decision rule between Wolverine sagas, Elsa workflows, and Hangfire jobs; Elsa activity authoring; bookmarks and signals; Hangfire recurring/scheduled/fire-and-forget jobs; dashboard auth; OTel propagation; PostgreSQL persistence. Use whenever a feature needs scheduled, recurring, or long-lived stateful work that isn't pure event-driven choreography.
when_to_load:
  - Task mentions: workflow, elsa, activity, signal, bookmark, human in the loop, hangfire, job, scheduled, recurring, cron, background, batch, dashboard
  - Files touched: any *Workflow.cs, *Activity.cs, *Job.cs, recurring jobs registration, Elsa workflow definitions (JSON or builders)
co_loads_with:
  - wolverine-patterns (saga decision-rule comparison)
  - persistence-patterns (both engines persist state in PG)
  - backend-feature-patterns (job/activity handlers follow handler-shape rules)
references:
  - keycloak-patterns (dashboard auth)
  - observability-backend (OTel propagation through Elsa + Hangfire — Phase 5 placeholder)
---

# Workflow and Jobs Patterns

## 1. Mental model + decision rule

|                  | Wolverine saga                | Elsa workflow                  | Hangfire job                  |
|---|---|---|---|
| **Lifespan**     | seconds-to-hours              | hours-to-months (with human waits) | milliseconds-to-minutes (no waiting) |
| **State**        | correlation-id keyed; saga state in DB | full workflow state in DB; resumable across deploys | job arguments only (no persisted state between executions) |
| **Human in loop?** | no                          | yes (signals, bookmarks, forms) | no |
| **Cron / recurring?** | no                       | no (schedule via activity)     | yes (cron, Hangfire's primary use case) |
| **Branching logic** | code only                  | designer + code                | code only |
| **Compensation**  | saga timeouts                 | workflow exceptions             | manual via retry filter |
| **Best fit**     | "scan → process → publish" (event-driven choreography) | "approval chain that waits 7 days for human action" | "every night at 2am, purge orphan quarantine blobs" |

**Decision rule (skim):**

- Event-driven coordination, short-lived, no human → **Wolverine saga**
- Human waits, long-lived, durable form/signal → **Elsa workflow**
- Recurring or scheduled background work, no event waiting → **Hangfire job**

When in doubt: if you find yourself reaching for a saga-with-timer-that-waits-for-human, that's an Elsa workflow. If you find yourself reaching for a Hangfire job that publishes a Wolverine event, that's correct — the job's body should be `bus.InvokeAsync(command, ct)` (see §8).

## 2. Elsa workflows: structure

A workflow is a composition of **Activities**. Activities are .NET classes implementing `IActivity` (or inheriting `CodeActivity` for synchronous one-shot work). Workflows are persisted to PostgreSQL (`elsa.*` schema) and **resumable across app restarts**.

Two definition styles:

| Style | When |
|---|---|
| **Programmatic** (C# builder, `WorkflowBase`) | Code-first workflows under source control — the default for engineering-owned workflows. |
| **JSON / designer** | Business-user-composed workflows. Out of scope for this skill (deployment + designer hosting concern). |

```csharp
namespace YourContext.Workflows.Approval;

public sealed class ListingApprovalWorkflow : WorkflowBase
{
    public static readonly string DefinitionId = nameof(ListingApprovalWorkflow);

    protected override void Build(IWorkflowBuilder builder)
    {
        builder.WithDefinitionId(DefinitionId).WithVersion(1);
        builder.Root = new Sequence
        {
            Activities =
            [
                new SetVariable<Guid> { VariableName = "ListingId", Value = new(ctx => ctx.GetInput<Guid>()) },
                // Bookmark: pauses here until an external signal arrives (see §4)
                new Event<ApprovalDecision>("listing-approval-decided"),
                new If(ctx => ctx.GetVariable<ApprovalDecision>("decision")!.Approved)
                {
                    Then = new PublishApproved(),
                    Else = new PublishRejected(),
                },
            ]
        };
    }
}
```

Recommendation: programmatic for everything except designer-driven business workflows.

## 3. Elsa activities

This skill owns the activity authoring shape.

- Activity = .NET class with the `[Activity]` attribute (display name, category).
- Inputs and outputs declared as `Input<T>` / `Output<T>` properties.
- Inject services via constructor — DI works inside activities.
- **Critical rule:** activities call into `IMessageBus` (Wolverine) for cross-context side effects, NOT directly into other bounded contexts' repositories. An activity is a workflow primitive; it does not own business logic.
- Activities return success or set output values; throw `WorkflowFaultException` for unrecoverable faults.
- Unit-test by instantiating the activity, setting inputs, and calling `ExecuteAsync` with a mocked `ActivityExecutionContext`.

```csharp
[Activity("YourContext", "Notifications", "Send SLA breach alert via Wolverine integration event")]
public sealed class TriggerSlaBreachAlert(IMessageBus bus) : CodeActivity
{
    // ACTIVITY-INPUT: BookingId — the booking that breached SLA
    [Input(Description = "Booking ID to alert on")]
    public Input<Guid> BookingId { get; set; } = default!;

    [Output] public Output<bool> AlertSent { get; set; } = default!;

    protected override async ValueTask ExecuteAsync(ActivityExecutionContext ctx)
    {
        var id = ctx.Get(BookingId);
        await bus.PublishAsync(new BookingSlaBreachedIntegrationEvent(id, DateTimeOffset.UtcNow));
        ctx.Set(AlertSent, true);
    }
}
```

## 4. Bookmarks and signals (human-in-the-loop)

A **bookmark** is a workflow pause point waiting for an external signal. The `Event<TPayload>` activity creates the bookmark; an outside caller resumes the workflow by invoking the runtime with a matching activity input.

```csharp
// Inside the workflow definition
new Event<ApprovalDecision>("listing-approval-decided"),

// Signal sender — a FastEndpoints endpoint resumes the bookmark
public sealed class SubmitApprovalDecisionEndpoint(IWorkflowRuntime runtime, IAuthorizationService authz)
    : Endpoint<Request, Response>
{
    public override void Configure()
    {
        Post("/api/v1/listings/{ListingId}/approval");
        Policies("listings.approve");
    }

    public override async Task HandleAsync(Request req, CancellationToken ct)
    {
        // ABAC check — only the assigned reviewer can submit — see keycloak-patterns §6
        var ok = await authz.AuthorizeAsync(HttpContext.User, req, "CanApproveListing");
        if (!ok.Succeeded) { await this.ToHttpResultAsync<Response>(Error.Forbidden("Listing.NotReviewer"), ct); return; }

        await runtime.ResumeWorkflowsAsync(
            new BookmarkPayload("listing-approval-decided", req.ListingId),
            new ApprovalDecision(req.Approved, req.Reason),
            ct);

        await this.ToHttpResultAsync(ErrorOrFactory.From(new Response(Accepted: true)), r => r, ct);
    }
}
```

**Bookmark TTL** — workflows enforce a timeout by racing a `Timer` activity against the bookmark via `Fork`; whichever fires first wins. Never hardcode durations — read from configuration or a domain policy service. Never hold DB connections or locks open across a bookmark.

## 5. Workflow vs saga decision

> **Rule:** If the coordination is pure event-driven choreography with bounded duration and no human input, write a **Wolverine saga** (cross-ref `wolverine-patterns §7`). If the coordination waits on human action, has stages spanning hours/days, or needs a visual representation for non-developers, write an **Elsa workflow**.

**Failure modes.** Mis-choosing Elsa for short-lived event coordination → bloat, designer overhead, harder testing. Mis-choosing a saga for long-running human-wait → state-bleed across saga timeouts; the saga either expires too early or holds correlation state indefinitely.

**The two engines must not coordinate with each other directly.** If a saga needs an Elsa workflow to start, publish an integration event via Wolverine; let an Elsa "Listen for event" activity pick it up. The reverse is the same — Elsa activities don't subscribe to Wolverine events; they invoke commands via `IMessageBus`.

## 6. Hangfire: structure

Jobs persisted to PostgreSQL (`hangfire.*` schema, distinct from `elsa.*`); workers pulled from a connection pool. Four job kinds:

| Kind | API | When |
|---|---|---|
| **Recurring** | `RecurringJob.AddOrUpdate` with cron | nightly purges, daily rollups |
| **Scheduled** | `BackgroundJob.Schedule(...)` | one-shot future code execution with retries + dashboard visibility |
| **Fire-and-forget** | `BackgroundJob.Enqueue(...)` | run ASAP on a free worker; out-of-band work |
| **Continuation** | `BackgroundJob.ContinueJobWith(...)` | run after another job succeeds |

**When to choose vs Wolverine scheduled message:** `bus.ScheduleAsync` is for one-shot future **message delivery** (publish this event in 10 minutes). Hangfire is for one-shot future **code execution** with retries, dashboard visibility, and persistence (rebuild the search index tonight at 2am). The line: are you delivering a message or running a piece of code?

## 7. Hangfire job class shape

This skill owns the job authoring shape.

- Plain .NET class with at least one public method; DI works.
- Job arguments must be JSON-serializable (Hangfire stores them in the `hangfire.job` table).
- Long-running methods accept a `CancellationToken` from `IJobCancellationToken` — honored on worker shutdown or manual abort.
- Inject `IMessageBus` to dispatch into the Wolverine pipeline; the outbox does **not** apply directly because the job is not inside a DbContext transaction (see §8).
- Naming: `<Aggregate><Purpose>Job` (e.g. `QuarantineCleanupJob`, `SearchReindexJob`).

```csharp
namespace YourContext.Application.Files.Jobs;

public sealed class QuarantineCleanupJob(IMessageBus bus)
{
    // CRON: 0 2 * * *  — daily at 02:00 UTC, registered in §9
    public Task Run(CancellationToken ct) =>
        bus.InvokeAsync(new PurgeAbandonedQuarantineUploadsCommand(OlderThan: TimeSpan.FromHours(24)), ct);
}
```

This is the canonical shape — the job body is a single `bus.InvokeAsync` call (see §8 for why). The actual business logic lives in `PurgeAbandonedQuarantineUploadsCommandHandler` and follows `backend-feature-patterns §3` rules.

## 8. Hangfire transaction & outbox interaction

> **Rule:** A Hangfire job is NOT inside a Wolverine `[Transactional]` scope. If the job mutates state AND needs to publish events, the job MUST either (a) call into a Wolverine command handler via `IMessageBus.InvokeAsync(command, ct)` — which IS transactional — or (b) wrap its work in an explicit unit-of-work that binds the outbox manually.

**Failure mode.** Direct `_repo.SaveChangesAsync()` + `_bus.PublishAsync()` inside a Hangfire job → dual-write risk identical to the one `wolverine-patterns §4` calls out: if the broker is down between the DB commit and the publish, the state is committed but the event is lost.

**Preferred pattern: the job's body is one line.**

```csharp
public sealed class SearchReindexJob(IMessageBus bus)
{
    public Task Run(string aliasName, CancellationToken ct) =>
        bus.InvokeAsync(new RunSearchReindexCommand(aliasName), ct);
}
```

The command handler does the real work transactionally — `[Transactional]`, EF Core, outbox-bound publishes. The Hangfire layer is just the scheduler.

## 9. Recurring jobs registration

Registered at startup via an extension method on the host. Cron format: standard 5-field cron; prefer `Cron.Daily(2)` for readability when applicable.

```csharp
public static IGlobalConfiguration AddYourContextRecurringJobs(this IGlobalConfiguration cfg)
{
    // JOB-IDEMPOTENT: the purge command checks "already-purged" by quarantine-bucket key; safe on overlap
    // CRON: daily at 02:00 UTC
    RecurringJob.AddOrUpdate<QuarantineCleanupJob>("uploads.quarantine-cleanup", j => j.Run(default!), Cron.Daily(2));
    RecurringJob.AddOrUpdate<SearchReindexJob>("search.listings-reindex", j => j.Run("listings", default!), Cron.Weekly(DayOfWeek.Sunday, 3));
    return cfg;
}
```

Job ID convention: `<aggregate>.<purpose>` (kebab-case in the ID, PascalCase for the class). **Recurring jobs MUST be idempotent** — running the same job twice on overlap is a no-op (annotate the dedup site with `// JOB-IDEMPOTENT:`).

## 10. Reindex example

The Elasticsearch alias-based reindex (see `elasticsearch-patterns §9`) is the canonical heavy Hangfire job. The job streams source-of-truth records via Dapper (see `persistence-patterns §4`), batches them through `IBulkIndexer`, then swaps the alias. Progress is persisted in a small per-job-instance table so a restart picks up at the next batch.

```csharp
// Job is a thin shell; the command handler owns the reindex pipeline
public sealed class SearchReindexJob(IMessageBus bus)
{
    public Task Run(string aliasName, CancellationToken ct) =>
        bus.InvokeAsync(new RunSearchReindexCommand(aliasName, BatchSize: 1_000), ct);
}

// In the handler (Application layer) — sketch
[Transactional]
public sealed class RunSearchReindexHandler(IListingsReindexReader reads, IBulkIndexer indexer, IReindexProgressStore progress)
{
    public async Task<ErrorOr<Success>> Handle(RunSearchReindexCommand cmd, CancellationToken ct)
    {
        var newIndex = $"{cmd.AliasName}_{DateTime.UtcNow:yyyyMMddHHmm}";
        var checkpoint = await progress.GetOrCreateAsync(cmd.AliasName, ct);
        await foreach (var batch in reads.StreamSinceAsync(checkpoint.LastId, cmd.BatchSize, ct))
        {
            await indexer.BulkAsync(newIndex, batch, ct);
            await progress.SaveAsync(cmd.AliasName, batch[^1].Id, ct);
        }
        await indexer.SwapAliasAsync(cmd.AliasName, checkpoint.PreviousIndex, newIndex, ct);
        return Result.Success;
    }
}
```

## 11. Dashboards (Hangfire + Elsa)

Both dashboards live under admin-only paths and require Keycloak-authenticated platform admins. Same auth shape for both — JWT validated via the standard `JwtBearer` middleware, then a dashboard-specific authorization filter requires the `platform.admin` role.

```csharp
public sealed class HangfireDashboardAuthFilter : IDashboardAuthorizationFilter
{
    public bool Authorize(DashboardContext context)
    {
        var http = context.GetHttpContext();
        return http.User.Identity?.IsAuthenticated == true
            && http.User.HasClaim("realm_access.roles", "platform.admin");
    }
}

// Registration
app.UseHangfireDashboard("/hangfire", new DashboardOptions { Authorization = [new HangfireDashboardAuthFilter()] });
```

Elsa dashboard (`/elsa-studio`) uses the same pattern. See `keycloak-patterns §5` for the `platform.admin` policy registration. Both dashboards are reserved for the admin segment — never exposed via the customer portal.

## 12. OTel propagation

- **Elsa:** traces propagate via `System.Diagnostics.Activity`; each activity execution becomes a span. The workflow instance id is carried as a span attribute.
- **Hangfire:** a `JobFilterAttribute` captures `traceparent` at enqueue and restores it on execute, so the job runs in the same trace as the enqueuer.

Trace-id is part of the saga/workflow correlation state for cross-correlation. The exact filter and instrumentation lives in `observability-backend` (Phase 5 placeholder).

## 13. Anti-patterns

- Hangfire job that does `_repo.SaveChangesAsync()` + `_bus.PublishAsync()` directly — dual-write risk. Use `_bus.InvokeAsync(command, ct)` instead.
- Elsa activity that reaches into another bounded context's repository directly — publish via Wolverine and let the other context consume.
- Long-running work inside a Wolverine handler — push it into a Hangfire job; the handler enqueues.
- Hangfire job that takes hours — split into chunked recurring (`BatchSize`) or escalate to Elsa.
- Mutable state held in an Elsa workflow variable when the workflow is supposed to be stateless between bookmarks — use external persistence.
- Recurring jobs without an idempotency check — overlapping runs create duplicate side effects.
- Hangfire dashboard exposed without an auth filter — information disclosure.
- `BackgroundJob.Enqueue` from inside a Wolverine handler that already publishes an integration event — pick one channel. Events for downstream choreography; jobs for scheduled work.
- Cron expressions with sub-minute granularity — use Wolverine scheduled messages instead.
- Using `IConsumer<T>` or MediatR-style dispatch inside an activity or job — both engines use `IMessageBus`.

## 14. Testing

**Elsa.** Workflow tests use the Elsa testing harness — instantiate the runtime in-memory, dispatch the trigger, advance bookmarks programmatically. Bookmark resumption tested by invoking `IWorkflowRuntime.ResumeWorkflowsAsync`.

**Hangfire.** Jobs are plain classes — unit-test them directly. Integration test the recurring registration via a hosted-service test fixture with an in-memory storage provider.

```csharp
[Fact]
public async Task QuarantineCleanupJob_invokes_command()
{
    var bus = Substitute.For<IMessageBus>();
    var job = new QuarantineCleanupJob(bus);
    await job.Run(default);
    await bus.Received(1).InvokeAsync(
        Arg.Is<PurgeAbandonedQuarantineUploadsCommand>(c => c.OlderThan == TimeSpan.FromHours(24)),
        Arg.Any<CancellationToken>());
}
```

## 15. Comment markers emitted by this skill

- `// ACTIVITY-INPUT:` — Elsa activity input binding.
- `// CRON:` — Hangfire recurring job cron expression annotation.
- `// JOB-IDEMPOTENT:` — annotates the dedup/skip check inside a recurring job (or the rationale at registration).

The canonical comment-markers index lives in `backend-feature-patterns §10`.

## 16. References

- `wolverine-patterns §3, §7, §9` — `InvokeAsync` semantics, sagas, scheduled messages.
- `persistence-patterns §4, §6` — Dapper streaming reads, schema separation (`elsa.*`, `hangfire.*`).
- `backend-feature-patterns §3, §5` — handler shape, `ErrorOr` contract (commands invoked by jobs follow these).
- `keycloak-patterns §5, §6` — dashboard auth + ABAC for signal endpoints.
- `file-pipeline-patterns §13` — `QuarantineCleanupJob` lives here (resolves the placeholder).
- `elasticsearch-patterns §9, §10` — `SearchReindexJob` lives here (resolves the placeholder).
- `observability-backend` — OTel propagation through Elsa + Hangfire (Phase 5 placeholder).
- `.specify/memory/system-context.md` — project-specific recurring jobs / workflow inventory.
