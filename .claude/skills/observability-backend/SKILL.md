---
name: observability-backend
description: "Load when: instrumenting C# .NET 10 services, BFF backend code, Wolverine handlers, or Hangfire jobs. OTel SDK + ASP.NET Core wiring, Serilog destructuring, Wolverine/Hangfire trace propagation, IOptionsMonitor<ObservabilityOptions> dynamic sampler + log level, PII redaction in-process, Sentry .NET. Read observability-contracts first."
---

# Observability — Backend (.NET)

## Purpose
.NET implementation of the contracts defined in `observability-contracts`. Covers C# services (FastEndpoints / clean-arch), the BFF backend code (Next.js route handlers can stay TypeScript — see `observability-frontend` for the BFF runtime-config endpoint), Wolverine consumers, and Hangfire jobs.

**Read `observability-contracts` first.** This skill assumes you know the resource attribute schema, runtime-config shape, PII deny-list, and span naming conventions.

## Core Rules

### Pipeline (.NET side)
```
.NET service ─OTel SDK (OTLP/gRPC)─► OTel Collector
            ─Serilog → OTel logs──►
            ─Sentry .NET (Sentry-compatible DSN)─► GlitchTip
```

* OTel SDK is the only telemetry API for traces and metrics. Never use Jaeger/Prometheus client libraries directly.
* Serilog writes to OTel via `Serilog.Sinks.OpenTelemetry`. Don't add another log sink to ship logs upstream — the collector is the single egress point.
* Sentry .NET ships unhandled exceptions only. Handled errors stay in Serilog/OTel logs.

### Required Packages
* `OpenTelemetry.Extensions.Hosting`
* `OpenTelemetry.Exporter.OpenTelemetryProtocol`
* `OpenTelemetry.Instrumentation.AspNetCore`
* `OpenTelemetry.Instrumentation.Http`
* `OpenTelemetry.Instrumentation.EntityFrameworkCore`
* `Npgsql.OpenTelemetry`
* `OpenTelemetry.Instrumentation.Runtime` + `.Process`
* `Serilog.AspNetCore` + `Serilog.Sinks.OpenTelemetry` + `Serilog.Enrichers.Span`
* `Sentry.AspNetCore`

### Startup Validation
Fail fast on missing observability config. The host MUST throw on startup if any of these are unset:
* `Observability:ServiceName`
* `Observability:Environment`
* `Observability:OtlpEndpoint`

Without `service.name` + `deployment.environment`, Loki labels become useless and dashboards break (see `observability-contracts` Loki Label Allow-List).

### Runtime Configuration via `IOptionsMonitor<ObservabilityOptions>`
Source priority (later wins):
1. `appsettings.json`
2. Environment variables (`Observability__TraceSampleRate=0.1`)
3. Mounted ConfigMap file (`/etc/config/observability.json`) — `IOptionsMonitor` watches it via file provider.

Apply changes live via:
* **OTel sampler** — custom `Sampler` reads `IOptionsMonitor.CurrentValue` inside `ShouldSample()` (the SDK builds the provider once; the sampler is the only mutable surface).
* **Serilog level** — `LoggingLevelSwitch.MinimumLevel` updated in `IOptionsMonitor.OnChange` callback.
* **PII deny-list** — destructuring policy reads `IOptionsMonitor.CurrentValue` per `TryDestructure` call.

### Trace Context Propagation Across the Two Manual Hops
Auto-instrumentation handles HTTP and EF Core. The two hops you must wire manually:

**Wolverine outbox** — outgoing middleware injects `traceparent` into envelope headers; incoming middleware extracts and starts a child span named `wolverine.handle <MessageType>`.

**Hangfire jobs** — `IClientFilter`/`IServerFilter` captures `Activity.Current.Id` at enqueue (`OnCreating`) and restores it at execution (`OnPerforming`), starting a span named `hangfire.job <JobName>`.

### Logging Discipline
* **Every log line includes `TraceId` and `SpanId`** when an Activity is active. `Serilog.Enrichers.Span` does this — make it mandatory.
* Use **structured logging only** (`logger.LogInformation("listing {ListingId} activated", id)`, never string concatenation).
* `Information` level is the production default. Use `Debug` only behind a runtime flag.
* **Never log handled exceptions to Sentry/GlitchTip.** Convention: GlitchTip = unhandled / fatal; Serilog = handled / warning.
* PII fields in log properties get redacted by the destructuring policy before serialization (defense-in-depth — the collector also redacts).

### Metrics
* Use `Meter` API only.
* Auto-instrumentation provides RED for HTTP, runtime metrics, and process metrics.
* For consumers/jobs, manually emit `messaging.consumer.duration`, `messaging.consumer.errors`, `hangfire.job.duration`, `hangfire.job.failures`.
* Custom business metrics use the `YourContext.*` (or your bounded-context) prefix.
* **Cardinality budget**: 100 unique label combinations per metric. User/tenant data goes to logs.

### PII Redaction (In-Process — Authoritative Layer)
* `PiiDestructuringPolicy` for Serilog, reading deny-list from `IOptionsMonitor`.
* `PiiRedactionSpanProcessor` for OTel spans (same deny-list applied to span attributes).
* Default deny-list defined in `observability-contracts`. Per-service `AdditionalPiiDenyFields` and `PiiAllowFields` come from `ObservabilityOptions`.

## Patterns / Examples

### `Program.cs` — single source of truth
```csharp
// Bind options + watch ConfigMap
builder.Services.AddOptions<ObservabilityOptions>()
    .Bind(builder.Configuration.GetSection("Observability"))
    .ValidateDataAnnotations();

builder.Configuration.AddJsonFile(
    "/etc/config/observability.json", optional: true, reloadOnChange: true);

// Startup validation — fail fast
var serviceName = builder.Configuration["Observability:ServiceName"]
    ?? throw new InvalidOperationException("Observability:ServiceName missing");
var environment = builder.Configuration["Observability:Environment"]
    ?? throw new InvalidOperationException("Observability:Environment missing");

builder.Services.AddSingleton<RuntimeRatioSampler>();

builder.Services.AddOpenTelemetry()
    .ConfigureResource(r => r
        .AddService(
            serviceName: serviceName,
            serviceNamespace: "directory",
            serviceVersion: typeof(Program).Assembly.GetName().Version?.ToString())
        .AddAttributes(new Dictionary<string, object>
        {
            ["deployment.environment"] = environment,
            ["service.instance.id"]    = Environment.MachineName,
        }))
    .WithTracing(t => t
        .SetSampler(sp => sp.GetRequiredService<RuntimeRatioSampler>())
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddEntityFrameworkCoreInstrumentation()
        .AddNpgsql()
        .AddSource("Wolverine")
        .AddSource("Hangfire")
        .AddProcessor<PiiRedactionSpanProcessor>()
        .AddOtlpExporter())
    .WithMetrics(m => m
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddRuntimeInstrumentation()
        .AddProcessInstrumentation()
        .AddMeter("YourContext.*")
        .AddOtlpExporter());

// Serilog — level switch bound to IOptionsMonitor
var levelSwitch = new LoggingLevelSwitch(LogEventLevel.Information);
builder.Host.UseSerilog((ctx, sp, lc) =>
{
    var monitor = sp.GetRequiredService<IOptionsMonitor<ObservabilityOptions>>();
    levelSwitch.MinimumLevel = ParseLevel(monitor.CurrentValue.LogMinimumLevel);
    monitor.OnChange(o => levelSwitch.MinimumLevel = ParseLevel(o.LogMinimumLevel));

    lc.MinimumLevel.ControlledBy(levelSwitch)
      .Enrich.FromLogContext()
      .Enrich.WithSpan()
      .Destructure.With(new PiiDestructuringPolicy(monitor))
      .WriteTo.OpenTelemetry(o =>
      {
          o.Endpoint = ctx.Configuration["Observability:OtlpEndpoint"];
          o.ResourceAttributes = new Dictionary<string, object>
          {
              ["service.name"]            = serviceName,
              ["deployment.environment"]  = environment,
          };
      });
});

// Sentry/GlitchTip — unhandled exceptions only
builder.WebHost.UseSentry(o =>
{
    o.Dsn         = builder.Configuration["Sentry:Dsn"];
    o.Release     = typeof(Program).Assembly.GetName().Version?.ToString();
    o.Environment = environment;
    o.TracesSampleRate = 0;            // tracing handled by OTel
    o.SetBeforeSend(PiiScrubber.Scrub);
});

static LogEventLevel ParseLevel(string s) =>
    Enum.TryParse<LogEventLevel>(s, true, out var l) ? l : LogEventLevel.Information;
```

### `RuntimeRatioSampler` (the only mutable surface in OTel .NET)
```csharp
public sealed class RuntimeRatioSampler(IOptionsMonitor<ObservabilityOptions> opts) : Sampler
{
    public override SamplingResult ShouldSample(in SamplingParameters p)
    {
        var o = opts.CurrentValue;
        if (!o.TracingEnabled) return new SamplingResult(SamplingDecision.Drop);

        var rate = Math.Clamp(o.TraceSampleRate, 0.0, 1.0);
        if (rate >= 1.0) return new SamplingResult(SamplingDecision.RecordAndSample);
        if (rate <= 0.0) return new SamplingResult(SamplingDecision.Drop);

        // Deterministic on traceId so a sampled trace stays sampled across services.
        var idHigh = BitConverter.ToUInt64(p.TraceId.ToByteArray(), 8);
        var threshold = (ulong)(rate * ulong.MaxValue);
        return idHigh < threshold
            ? new SamplingResult(SamplingDecision.RecordAndSample)
            : new SamplingResult(SamplingDecision.Drop);
    }
    public override string Description => "RuntimeRatioSampler";
}
```

### `PiiDestructuringPolicy` (live deny-list)
```csharp
public class PiiDestructuringPolicy(IOptionsMonitor<ObservabilityOptions> opts) : IDestructuringPolicy
{
    private static readonly HashSet<string> DefaultDeny = new(StringComparer.OrdinalIgnoreCase)
    {
        "password","passwd","pwd","secret","token","api_key","apikey","authorization",
        "ssn","sin","tax_id","national_id","email","email_address","phone","phone_number",
        "mobile","credit_card","card_number","cvv","pan","date_of_birth","dob",
        "address","street","postal_code","zip","ip_address","ip",
    };

    public bool TryDestructure(object value, ILogEventPropertyValueFactory factory, out LogEventPropertyValue result)
    {
        if (value is null) { result = null!; return false; }

        var o = opts.CurrentValue;
        var denied = new HashSet<string>(
            DefaultDeny.Concat(o.AdditionalPiiDenyFields), StringComparer.OrdinalIgnoreCase);
        denied.ExceptWith(o.PiiAllowFields);

        var members = value.GetType().GetProperties().Select(p => new LogEventProperty(
            p.Name,
            denied.Contains(p.Name)
                ? new ScalarValue("[REDACTED]")
                : factory.CreatePropertyValue(p.GetValue(value), destructureObjects: true)));

        result = new StructureValue(members);
        return true;
    }
}
```

### Wolverine — outbox trace propagation
```csharp
public class TracePropagationOutgoingMiddleware : IOutgoingMiddleware
{
    public ValueTask InvokeAsync(Envelope envelope, IMessageContext context, Func<ValueTask> next)
    {
        if (Activity.Current is { } activity)
        {
            Propagators.DefaultTextMapPropagator.Inject(
                new PropagationContext(activity.Context, Baggage.Current),
                envelope.Headers,
                (headers, key, value) => headers[key] = value);
        }
        return next();
    }
}

public class TracePropagationIncomingMiddleware : IIncomingMiddleware
{
    public async ValueTask InvokeAsync(Envelope envelope, IMessageContext context, Func<ValueTask> next)
    {
        var parentContext = Propagators.DefaultTextMapPropagator.Extract(
            default, envelope.Headers,
            (headers, key) => headers.TryGetValue(key, out var v) ? new[] { v } : Array.Empty<string>());

        using var activity = ActivitySource.StartActivity(
            $"wolverine.handle {envelope.MessageType}",
            ActivityKind.Consumer,
            parentContext.ActivityContext);

        activity?.SetTag("messaging.system", "wolverine");
        activity?.SetTag("messaging.operation", "receive");
        activity?.SetTag("messaging.destination", envelope.MessageType);
        await next();
    }
}
```

### Hangfire — trace propagation across the job boundary
```csharp
public class TraceContextJobFilter : IClientFilter, IServerFilter
{
    private const string TraceParentKey = "TraceParent";
    private const string TraceStateKey  = "TraceState";

    public void OnCreating(CreatingContext context)
    {
        if (Activity.Current is { } activity)
        {
            context.SetJobParameter(TraceParentKey, activity.Id);
            context.SetJobParameter(TraceStateKey, activity.TraceStateString);
        }
    }
    public void OnCreated(CreatedContext context) { }

    public void OnPerforming(PerformingContext context)
    {
        var parent = context.GetJobParameter<string>(TraceParentKey);
        var state  = context.GetJobParameter<string>(TraceStateKey);
        if (string.IsNullOrEmpty(parent)) return;

        var activity = ActivitySource.StartActivity(
            $"hangfire.job {context.BackgroundJob.Job.Method.Name}",
            ActivityKind.Consumer,
            parent);
        if (activity is not null && !string.IsNullOrEmpty(state))
            activity.TraceStateString = state;

        context.Items["__trace_activity"] = activity;
    }

    public void OnPerformed(PerformedContext context)
    {
        if (context.Items.TryGetValue("__trace_activity", out var a) && a is Activity activity)
            activity.Dispose();
    }
}

// Registration: GlobalJobFilters.Filters.Add(new TraceContextJobFilter());
```

### Custom business metric (cardinality-safe)
```csharp
public class ListingMetrics
{
    private readonly Counter<long> _activated;
    public ListingMetrics(IMeterFactory factory)
    {
        var meter = factory.Create("YourContext.Listings");
        _activated = meter.CreateCounter<long>("directory.listings.activated.count");
    }

    // GOOD — bounded labels (status, region)
    public void RecordActivation(string status, string region) =>
        _activated.Add(1, new("status", status), new("region", region));

    // BAD — DO NOT add user_id, listing_id, tenant_id as labels. Log them instead.
}
```

## Operational Controls (backend knobs)
All apply via ConfigMap reload; no pod restart required.

| Knob | ConfigMap field | Effect | Propagation |
|---|---|---|---|
| Disable tracing | `Observability.TracingEnabled=false` | `RuntimeRatioSampler` returns `Drop` for all spans | ~5s |
| Throttle trace sample rate | `Observability.TraceSampleRate=0.01` | Per-span decision uses new rate | ~5s |
| Adjust Serilog level | `Observability.LogMinimumLevel=Warning` | `LoggingLevelSwitch` applies live | ~5s |
| Add PII deny entries | `Observability.AdditionalPiiDenyFields=["..."]` | Destructuring policy reads new list per event | ~5s |
| Allow specific PII field | `Observability.PiiAllowFields=["email"]` | Bypass redaction for this service only — **PR-justified** | ~5s |

What you cannot change at runtime in .NET OTel: the provider composition (instrumentations, exporters). That's a deploy.

## When to Use
* Wiring a new .NET service or BFF backend route handler for observability
* Adding a Wolverine handler or Hangfire job
* Reviewing a backend PR that adds logging, metrics, or error reporting
* Investigating "missing trace" or "log not in Loki" from a service

## When NOT to Use
* Frontend instrumentation — see `observability-frontend`
* OTel Collector / Loki / Jaeger / Prometheus / GlitchTip deployment — see `observability-infra`
* Defining new contracts (resource attrs, JSON shape, deny-list) — see `observability-contracts`, requires ADR
* Audit logging for security events — covered by `auth-patterns`
