---
name: workflow-patterns
description: "Load when: designing or implementing business workflows, SLA enforcement, breach alerts, or multi-channel notifications. Elsa v3 embedded workflows in .NET 10."
---

# Workflow Patterns (Elsa v3)

## Purpose
Production patterns for Elsa v3 embedded workflows in .NET 10 services. Covers workflow design, activity authoring, SLA timers, breach alert escalation, multi-channel notification routing, and persistence strategy. Elsa v3 runs in-process — no separate workflow server required.

## Core Rules

### Elsa v3 Embedding
* Elsa runs embedded inside the ASP.NET Core process. Register via `services.AddElsa(elsa => {...})`.
* Persistence: always use PostgreSQL (`elsa.UseEntityFrameworkPersistence(ef => ef.UsePostgres(...))`) — never in-memory in production.
* Use the Elsa Studio dashboard (separate host) for workflow monitoring only. Not required for runtime.
* Elsa's runtime and definition APIs are internal — expose only domain-level trigger endpoints to other services.
* One workflow definition per business process. Do not create generic "mega-workflows" that handle multiple unrelated processes.

### Workflow Design
* Model workflows as explicit state machines — every state and every transition named in business terms.
* Keep workflows thin: activities orchestrate calls to domain services; business logic lives in domain/application layer, not inside activities.
* **Activities dispatch domain operations through MediatR** — they never call repositories, `DbContext`, or domain methods directly. An activity that needs to mutate state injects `ISender` and sends the appropriate `ICommand` / `ICommand<T>` (see `csharp-clean-arch` and `messaging-patterns`). An activity that needs to read state sends an `IQuery<T>`. This keeps the CQRS boundary intact: a workflow is just another caller of the application layer, not a parallel pathway around it. Validation, authorization, transactions, outbox publishing, and pipeline behaviours all run automatically because the call goes through the same MediatR pipeline as an HTTP request.
* Activities **never** call EF Core, Dapper, MassTransit `IPublishEndpoint`, or Redis directly — those are infrastructure details owned by command/query handlers. If a domain operation does not yet have a MediatR handler, create one rather than reaching past it from inside the activity.
* Workflows are long-running and durable — do not assume in-memory state survives. Persist all correlation data in workflow variables.
* Correlation: every workflow instance correlates to a business entity ID (`listingId`, `bookingId`). Use `CorrelateWithAsync` to prevent duplicate instances.
* Workflow triggers: HTTP endpoint, MassTransit message, timer. Prefer message-based triggers for reliability.

### Activity Authoring
* Custom activities inherit from `Activity` or `CodeActivity` for simple logic, `Composite` for sub-workflows.
* Each activity: single responsibility. One activity = one side effect or one decision.
* Activities should be idempotent — Elsa may replay activities on resume.
* Inject domain services via constructor DI into activities. Do not use service locator.
* Declare input/output ports explicitly for branching decisions:
  ```csharp
  [Output] public Output<bool> IsApproved { get; set; } = default!;
  ```
* Handle activity failures by throwing — Elsa catches and marks the step as faulted. Do not swallow exceptions inside activities.

### SLA Timers & Breach Alerts
* Use `Timer` or `Delay` activities for SLA enforcement — not Hangfire for workflow-owned timers.
* Pattern for SLA breach:
  1. Start timer activity when process starts.
  2. Run `Fork` to wait on either business event (completion) or timer expiry.
  3. On timer expiry branch: trigger escalation activity.
  4. On business event: cancel the timer branch (`CancelSignal` / join).
* Never hardcode timer durations — read from configuration or domain policy service.
* Breach alert payload: include entity ID, process name, SLA deadline, current state, escalation level.

### Multi-Channel Notifications
* Notification routing activity: determine channels from user preferences and notification type.
* Supported channels: Email, SMS, Push, In-App. Channel selection is runtime-determined — do not hardcode.
* Notification activity responsibilities: build payload, call notification service (injected), record delivery attempt.
* Retry on notification failure within the activity — configurable per channel (email: 3 retries, SMS: 5 retries).
* Notification failures are non-fatal to the workflow — log WARN, continue workflow.
* Track notification delivery status in workflow variables for audit.

### Persistence & Resumption
* Workflow state is persisted at every bookmark (wait point). Safe to restart the process.
* Bookmarks: `Delay`, `Event`, `Signal`, `HttpEndpoint` all create bookmarks automatically.
* Never hold database connections or locks open across a bookmark — release before yielding.
* Use workflow variables (not process-level state) for correlation data and intermediate results.

### Observability
* Log workflow lifecycle events: started, activity executed, faulted, completed, cancelled. Include `workflow_instance_id` and correlation ID in every log.
* Emit metrics: `workflow_started_total{workflow}`, `workflow_completed_total{workflow}`, `workflow_faulted_total{workflow,activity}`, `workflow_duration_seconds{workflow}`.
* SLA breach metric: `sla_breach_total{workflow,level}` — alert on this in Prometheus/Grafana.

## Patterns / Examples

### Workflow registration
```csharp
services.AddElsa(elsa =>
{
    elsa.UseEntityFrameworkPersistence(ef => ef.UsePostgreSql(connectionString));
    elsa.UseWorkflowManagement();
    elsa.UseWorkflowRuntime();
    elsa.UseDefaultAuthentication();
    elsa.AddWorkflow<ListingApprovalWorkflow>();
    elsa.AddWorkflow<BookingSlaWorkflow>();
});
```

### SLA enforcement workflow (C# DSL)
```csharp
public class BookingSlaWorkflow : WorkflowBase
{
    public static readonly string DefinitionId = nameof(BookingSlaWorkflow);

    protected override void Build(IWorkflowBuilder builder)
    {
        builder
            .WithDefinitionId(DefinitionId)
            .WithVersion(1);

        builder.Root = new Sequence
        {
            Activities =
            [
                new SetVariable<Guid> { VariableName = "BookingId", Value = new(ctx => ctx.GetInput<Guid>()) },
                new Fork
                {
                    Branches =
                    [
                        // Branch 1: wait for booking confirmation event
                        new Sequence
                        {
                            Activities =
                            [
                                new WaitForBookingConfirmed(), // custom activity
                                new CancelTimer { TimerId = "sla-timer" }
                            ]
                        },
                        // Branch 2: SLA breach timer
                        new Sequence
                        {
                            Activities =
                            [
                                new Timer { Duration = new(ctx => ctx.GetSlaFromPolicy()), Id = "sla-timer" },
                                new TriggerSlaBreachAlert(),   // custom activity
                                new SendMultiChannelNotification { Channel = NotificationChannel.All }
                            ]
                        }
                    ]
                }
            ]
        };
    }
}
```

### Custom activity
```csharp
[Activity("DirectoryService", "Notifications", "Send SLA breach alert via all configured channels")]
public class TriggerSlaBreachAlert(INotificationService notificationService, ILogger<TriggerSlaBreachAlert> logger)
    : CodeActivity
{
    [Input(Description = "Booking ID to alert on")]
    public Input<Guid> BookingId { get; set; } = default!;

    [Output]
    public Output<bool> AlertSent { get; set; } = default!;

    protected override async ValueTask ExecuteAsync(ActivityExecutionContext ctx)
    {
        var bookingId = ctx.Get(BookingId);
        logger.LogWarning("SLA breach triggered for booking {BookingId}", bookingId);

        await notificationService.SendSlaBreachAsync(bookingId, ctx.CancellationToken);
        ctx.Set(AlertSent, true);
    }
}
```

## When to Use
* Business processes with multiple steps, waits, and state
* SLA enforcement: deadlines that must trigger alerts/escalations if breached
* Multi-channel notification routing with retry and delivery tracking
* Approval workflows, booking flows, onboarding sequences
* Any long-running process that must survive service restarts

## When NOT to Use
* Simple fire-and-forget side effects → use MassTransit consumers or Hangfire
* Short-lived, synchronous request/response processes → direct application service
* Saga orchestration without SLA/timer requirements → MassTransit StateMachine (simpler)
* Infrastructure automation or CI/CD pipelines
