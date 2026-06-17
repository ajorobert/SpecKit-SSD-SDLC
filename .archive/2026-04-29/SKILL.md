---
name: observability-patterns
description: "Load when: instrumenting backend services or frontends for traces, metrics, logs, or error tracking. OpenTelemetry SDK → OTel Collector → Jaeger/Loki/Prometheus pipeline, Serilog structured logging, PII redaction, Wolverine/MassTransit/Hangfire trace propagation, GlitchTip error tracking, frontend OTel JS / OTel React Native."
---

# Observability Patterns

## Purpose
Production patterns for unified observability across backend services and all three frontends. Single OpenTelemetry pipeline for traces, metrics, and logs — exported through one OTel Collector to Jaeger (traces), Loki (logs), and Prometheus (metrics). Errors flow to GlitchTip. PII is redacted before any signal leaves the process.

The goal is **one mental model**: every signal carries `trace_id` + `span_id`, every service emits the same resource attributes, and any incident can be traced from a frontend click → BFF span → service span → message consumer span → background job span without changing tools.

## Core Rules

### Pipeline Topology

```
┌─────────────────────────┐    ┌─────────────────────────┐
│ Backend services (.NET) │    │ Frontends (Next/React/  │
│  - OTel SDK (auto+      │    │  React Native)          │
│    manual instrumentation)│   │  - OTel JS / OTel RN    │
│  - Serilog → OTel logs  │    │  - GlitchTip SDK        │
└────────────┬────────────┘    └────────────┬────────────┘
             │ OTLP/gRPC                    │ OTLP/HTTP
             ▼                              ▼
        ┌────────────────────────────────────────┐
        │         OTel Collector (per env)        │
        │  receivers → processors → exporters     │
        │  - PII redaction processor              │
        │  - resource detection                   │
        │  - tail sampling (commented, ready)     │
        └──┬──────────────┬─────────────┬─────────┘
           │ traces       │ metrics     │ logs
           ▼              ▼             ▼
        Jaeger        Prometheus       Loki
        
        Errors (separate path):
        Frontends + Backends → GlitchTip (Sentry-compatible DSN)
```

* **OTel SDK is the only instrumentation API.** Never call Jaeger/Prometheus/Loki client libraries directly from application code.
* **OTel Collector is the only egress point.** Services and frontends never talk to Jaeger/Loki/Prometheus directly. This lets you add processors (redaction, sampling, batching) once, in one place.
* **GlitchTip uses the Sentry SDK** (Sentry-compatible). Errors and unhandled exceptions go to GlitchTip; do not duplicate them as OTel logs at `Error` level — pick one. Convention: **GlitchTip for unhandled exceptions and JS errors; Serilog/OTel logs for handled errors and warnings.**

### Sampling
* **Default: 100% sampling** (head sampling = `AlwaysOn`). Storage cost is the constraint, not collection cost; you can always sample down at the collector.
* Tail sampling lives in the collector config as a **commented-out block** with thresholds tuned to keep all errors + slow traces + a percentage of normal traffic. Uncomment when trace volume justifies it.
* Frontend RUM: 100% for errors, 10% for performance traces (browsers are noisy; head-sample at SDK).

### Resource Attributes (mandatory on every signal)
Every service and frontend MUST emit these resource attributes via OTel SDK:

| Attribute | Source | Example |
|---|---|---|
| `service.name` | env `OTEL_SERVICE_NAME` | `listings-api` |
| `service.namespace` | bounded context | `marketplace` |
| `service.version` | build metadata | `2026.04.29-a3f2c1d` |
| `service.instance.id` | hostname / pod name | `listings-api-7d9c8-x4kp2` |
| `deployment.environment` | env var | `prod` / `preprod` / `dev` |

These become Loki labels (see Cardinality Rules below) and Jaeger process tags. **Without `service.name` + `deployment.environment`, dashboards break** — make it a startup check that fails fast if missing.

### Loki Label Cardinality (READ THIS BEFORE TOUCHING LABELS)
Loki indexes by label combinations. High-cardinality labels destroy query performance and can OOM the ingester. Allowed labels are an explicit allow-list:

**Allowed Loki labels (bounded cardinality):**
* `service` (= `service.name`) — bounded by service count
* `env` (= `deployment.environment`) — bounded by env count
* `level` — bounded enum (`debug|info|warn|error|fatal`)

**Forbidden as labels** (must be log-line fields, queryable via `| json`):
* `trace_id`, `span_id` — unbounded
* `user_id`, `tenant_id`, `customer_id` — unbounded
* `request_id`, `correlation_id` — unbounded
* `endpoint_path`, `route`, `url` — high cardinality with parameterized routes
* `status_code` — looks bounded but combines multiplicatively with other labels
* `host`, `pod`, `instance` — covered by `service.instance.id` resource attribute, not a label

The forbidden list lives verbatim as a comment at the top of `infra/observability/otel-collector-config.yaml`:
> `# NEVER add anything to this list without checking cardinality first.`
> `# Each new label multiplies the index size; we have killed Loki ingesters at 3am over a single innocent-looking label. Trace/user/request IDs go IN the log line, not on it.`

### Trace Context Propagation (the cross-cutting headache)
W3C Trace Context (`traceparent`, `tracestate`) is the propagation format everywhere. Never use B3 or Jaeger native propagation — they don't survive cleanly across .NET/JS/RN boundaries.

| Hop | Mechanism |
|---|---|
| Browser → BFF | OTel JS auto-instrumentation injects `traceparent` on `fetch` / `XHR` |
| BFF → service | `HttpClient` auto-instrumentation propagates `traceparent` |
| HTTP → MediatR handler | Activity flows through async context (no work needed) |
| Command handler → Wolverine outbox | **Manual**: Wolverine envelope must carry `traceparent` header — see pattern below |
| Wolverine consumer → handler | Wolverine middleware extracts `traceparent` and starts child span |
| MassTransit producer → consumer | OTel MassTransit instrumentation propagates automatically |
| Anywhere → Hangfire job | **Manual**: capture trace context at enqueue, restore inside job filter — see pattern below |
| Service → Serilog log line | `LogContext.PushProperty("TraceId", Activity.Current?.TraceId)` via enricher |

Every log line MUST include `TraceId` and `SpanId` as structured fields when an Activity is active. The `Serilog.Enrichers.OpenTelemetry` package handles this — make it mandatory in service host registration.

### Span Naming (OTel Semantic Conventions)
* HTTP server: `<METHOD> <route-template>` — e.g., `POST /api/v1/listings/{id}/activate` (FastEndpoints route template, not the resolved URL)
* HTTP client: `<METHOD>` — e.g., `GET` (target host goes on `server.address` attribute)
* Database: `<db.operation> <db.collection>` — e.g., `SELECT listings`, `INSERT outbox_messages`
* Messaging (consumer): `<messaging.destination> receive` — e.g., `listing.activated.v1 receive`
* Messaging (producer): `<messaging.destination> publish`
* Hangfire jobs: `hangfire.job <JobName>` — no OTel semconv exists for this; this is our convention.
* Wolverine handlers: `wolverine.handle <MessageType>`

Set `messaging.system` (`rabbitmq`), `messaging.operation` (`receive`/`publish`), `messaging.destination` on every message span.

### Metrics
* Use OTel `Meter` API only. Never `prometheus-net` directly — keep one pipeline.
* **Required RED metrics on every HTTP endpoint** (FastEndpoints middleware emits these):
  * `http.server.request.duration` (histogram, seconds)
  * `http.server.request.count` (counter)
  * `http.server.request.errors` (counter, filtered to 5xx)
* **Required USE metrics for every consumer / job**:
  * `messaging.consumer.duration` (histogram, by `messaging.destination`)
  * `messaging.consumer.errors` (counter)
  * `hangfire.job.duration`, `hangfire.job.failures`
* Histogram bucket boundaries default to OTel exponential histograms — do not hand-tune unless you've measured.
* Custom business metrics: prefix with bounded-context name — `marketplace.listings.activated.count`. **Cardinality budget**: max 100 unique label combinations per metric. Anything user/tenant-scoped goes to logs, not metrics.

### PII Redaction (defense in depth)
PII redaction happens at **two layers** — never one:

1. **In-process (Serilog destructuring policy + OTel span processor)** — catches PII before it leaves the service. Authoritative.
2. **At the collector (attribute processor)** — backstop for misconfigured services and third-party libraries.

Shared deny-list (per service, configurable extension):

```
Default deny-list (matched case-insensitive on field name):
- password, passwd, pwd
- secret, token, api_key, apikey, authorization
- ssn, sin, tax_id, national_id
- email, email_address  (PII; redact unless explicitly allow-listed for a specific log)
- phone, phone_number, mobile
- credit_card, card_number, cvv, pan
- date_of_birth, dob
- address, street, postal_code, zip
- ip_address, ip          (regulated as PII in EU)
```

Redacted values become `[REDACTED]`. Values are **never** hashed (hashes leak via rainbow tables on bounded sets like phone numbers).

Per-service overrides live in `appsettings.json`:
```json
"Observability": {
  "PiiRedaction": {
    "AdditionalDenyFields": ["internal_ref"],
    "AllowFields": ["email"]   // explicit allow for this service only — must be justified in PR
  }
}
```

Allow-listing requires a one-line justification comment in the PR. Audit annually.

### Error Tracking (GlitchTip)
* GlitchTip is Sentry-API-compatible — use `Sentry.AspNetCore` and `Sentry` for browser/RN.
* DSN per service per environment, in env var `SENTRY_DSN` (named for SDK compatibility; the destination is GlitchTip).
* Source map upload: required for portal (Next.js), admin SPA (Vite), and mobile (Expo). CI step uploads on every release using `sentry-cli` against the GlitchTip endpoint.
* Release identifier matches `service.version` resource attribute — same string in OTel and GlitchTip so you can pivot between them.
* `traceparent` is attached to every GlitchTip event via OTel-Sentry integration so an error in GlitchTip links to the trace in Jaeger.
* `BeforeSend` hook applies the same PII deny-list as the OTel pipeline.
* **Do not log handled exceptions to GlitchTip.** Convention: GlitchTip = unhandled / fatal; OTel logs = handled / warning.

### Frontend Observability
* **Next.js portal**: `@opentelemetry/sdk-trace-web` + `@opentelemetry/instrumentation-fetch` + `@opentelemetry/instrumentation-document-load`. Sentry/GlitchTip SDK for errors. Source maps uploaded on `next build`.
* **React admin SPA**: same OTel JS packages. Vite plugin for source map upload to GlitchTip.
* **Expo RN app**: `@opentelemetry/sdk-trace-web` is incompatible with RN — use `@opentelemetry/sdk-node` polyfill or the community `expo-otel` wrapper. Sentry RN SDK for errors with Expo source map plugin.
* All three set the same resource attributes (`service.name` = `customer-portal` / `admin-spa` / `vendor-mobile`).
* **Never** ship raw OTel data from frontends to OTel collectors over the public internet — route through the BFF (Next.js portal) or a public OTLP HTTP receiver behind auth. Browsers cannot keep secrets, so the collector endpoint must accept anonymous traffic with strict rate limits and PII filtering.

### Runtime Configuration (no-redeploy controls)
Observability is the first thing operators want to turn down at 3am — and the last thing you want to redeploy under load. Every signal source (frontend or backend) reads its enable/disable flags and sample rates from a **runtime configuration layer**, not from baked-in env vars.

**Architecture:**
* **Frontends** read from a single `GET /api/runtime-config` endpoint exposed by the BFF. JSON shape covers all four frontend tools (OTel JS, Sentry/GlitchTip, PostHog, Clarity).
* **Backend services** bind `ObservabilityOptions` via `IOptionsMonitor<T>` so a Kubernetes ConfigMap remount applies live — no pod restart.
* **Failure mode is "off".** If the runtime-config endpoint fails, returns malformed JSON, or times out, the frontend defaults every tool to `enabled: false`. A config outage degrades observability, never the user-facing app.

**SDK runtime-mutability matrix (verified, do not invent):**

| SDK | Disable at runtime | Change sample rate at runtime | Mechanism |
|---|---|---|---|
| OTel JS (web/RN) | ✗ no public API to detach providers | ✗ sampler frozen at `TracerProvider` construction | Workaround: custom sampler that reads a mutable holder per `shouldSample()` call |
| Sentry JS (errors) | ✗ no `close-and-reopen` without re-init | Partial — `tracesSampler` callback can read a mutable holder per transaction; `sampleRate` (errors) cannot | Use `tracesSampler` function not `tracesSampleRate` number; for errors accept fixed rate or re-init on toggle |
| PostHog JS | ✓ `posthog.opt_out_capturing()` / `opt_in_capturing()` | Partial — autocapture toggle yes via `set_config({autocapture})`; session-recording sample rate is project-side | Document that recording rate is server-side |
| Clarity | ✗ no runtime API once script loads | ✗ no runtime sample-rate control | Conditional `<Script>` load only — once loaded, stays loaded until next page navigation |
| .NET OTel | ✗ provider built once | ✓ via custom `Sampler` reading `IOptionsMonitor` inside `ShouldSample` | See pattern below |
| Serilog | ✓ `LoggingLevelSwitch.MinimumLevel = ...` | n/a (level not rate) | Bind switch to `IOptionsMonitor` change callback |

**Source priority for backend `ObservabilityOptions`** (later wins):
1. `appsettings.json` (defaults)
2. Environment variables (`Observability__SampleRate=0.1`)
3. Mounted ConfigMap file (`/etc/config/observability.json`) — `IOptionsMonitor` watches it via file provider

**Frontend init timing rules:**
* Sentry/GlitchTip SDK init MUST happen synchronously in the document `<head>` to catch page-load errors. It reads from SSR-inlined config (Next.js) or a synchronous bootstrap module (Vite/RN with cached config).
* OTel JS and PostHog can lazy-init `afterInteractive` — they don't need to catch synchronous boot errors.
* React Native: config is fetched on app start, cached in `AsyncStorage`, and applied on **next** app boot — in-flight sessions keep their boot-time config. This is a hard limitation of mobile, document it in operator runbooks.

### Repository Layout
The OTel collector config is **committed to the source repo** as the source of truth. Pre-prod and prod must run byte-identical configs so prod issues reproduce in pre-prod:

```
infra/
  observability/
    otel-collector-config.yaml      # canonical, env-templated
    otel-collector-config.preprod.yaml  # generated from canonical, do not edit
    otel-collector-config.prod.yaml     # generated from canonical, do not edit
    grafana-dashboards/
      service-red.json
      messaging-overview.json
      logs-overview.json
    prometheus-rules/
      service-slo.yaml
    README.md
```

Deviations between pre-prod and prod require an ADR. The canonical config is the reference; deployment infra (Helm, Terraform) renders the env-specific files from it.

## Patterns / Examples

### .NET service host wiring (single source of truth)
```csharp
// Program.cs
builder.Services.AddOpenTelemetry()
    .ConfigureResource(r => r
        .AddService(
            serviceName: builder.Configuration["Observability:ServiceName"]
                ?? throw new InvalidOperationException("Observability:ServiceName missing"),
            serviceNamespace: "marketplace",
            serviceVersion: typeof(Program).Assembly.GetName().Version?.ToString())
        .AddAttributes(new Dictionary<string, object>
        {
            ["deployment.environment"] = builder.Configuration["Observability:Environment"]!,
            ["service.instance.id"] = Environment.MachineName,
        }))
    .WithTracing(t => t
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddEntityFrameworkCoreInstrumentation()
        .AddNpgsql()
        .AddSource("MassTransit")
        .AddSource("Wolverine")
        .AddSource("Hangfire")
        .AddProcessor<PiiRedactionSpanProcessor>()
        .AddOtlpExporter())
    .WithMetrics(m => m
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddRuntimeInstrumentation()
        .AddProcessInstrumentation()
        .AddMeter("Marketplace.*")
        .AddOtlpExporter());

// Serilog with trace correlation + PII redaction
builder.Host.UseSerilog((ctx, lc) => lc
    .ReadFrom.Configuration(ctx.Configuration)
    .Enrich.FromLogContext()
    .Enrich.WithSpan()                    // adds TraceId, SpanId
    .Destructure.With<PiiDestructuringPolicy>()
    .WriteTo.OpenTelemetry(o =>
    {
        o.Endpoint = ctx.Configuration["Observability:OtlpEndpoint"];
        o.ResourceAttributes = new Dictionary<string, object>
        {
            ["service.name"] = ctx.Configuration["Observability:ServiceName"]!,
            ["deployment.environment"] = ctx.Configuration["Observability:Environment"]!,
        };
    }));

// Sentry/GlitchTip for unhandled exceptions only
builder.WebHost.UseSentry(o =>
{
    o.Dsn = builder.Configuration["Sentry:Dsn"];
    o.Release = typeof(Program).Assembly.GetName().Version?.ToString();
    o.Environment = builder.Configuration["Observability:Environment"];
    o.TracesSampleRate = 0; // tracing handled by OTel, not Sentry
    o.SetBeforeSend(PiiScrubber.Scrub);
});
```

### Wolverine outbox: propagating trace context
```csharp
// Outgoing envelope middleware — capture trace context on publish
public class TracePropagationOutgoingMiddleware : IOutgoingMiddleware
{
    public ValueTask InvokeAsync(Envelope envelope, IMessageContext context, Func<ValueTask> next)
    {
        if (Activity.Current is { } activity)
        {
            var propagator = Propagators.DefaultTextMapPropagator;
            propagator.Inject(
                new PropagationContext(activity.Context, Baggage.Current),
                envelope.Headers,
                (headers, key, value) => headers[key] = value);
        }
        return next();
    }
}

// Incoming envelope middleware — restore trace context on handle
public class TracePropagationIncomingMiddleware : IIncomingMiddleware
{
    public async ValueTask InvokeAsync(Envelope envelope, IMessageContext context, Func<ValueTask> next)
    {
        var propagator = Propagators.DefaultTextMapPropagator;
        var parentContext = propagator.Extract(default, envelope.Headers,
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

### Hangfire: trace context across the job boundary
```csharp
// Capture trace context when enqueuing
public class TraceContextJobFilter : IClientFilter, IServerFilter
{
    private const string TraceParentKey = "TraceParent";
    private const string TraceStateKey = "TraceState";

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
        var state = context.GetJobParameter<string>(TraceStateKey);
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

// Registration
GlobalJobFilters.Filters.Add(new TraceContextJobFilter());
```

### Serilog PII destructuring policy
```csharp
public class PiiDestructuringPolicy(IOptions<PiiRedactionOptions> options) : IDestructuringPolicy
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
        var props = value.GetType().GetProperties();
        var denied = new HashSet<string>(DefaultDeny.Concat(options.Value.AdditionalDenyFields), StringComparer.OrdinalIgnoreCase);
        denied.ExceptWith(options.Value.AllowFields);

        var members = props.Select(p => new LogEventProperty(
            p.Name,
            denied.Contains(p.Name)
                ? new ScalarValue("[REDACTED]")
                : factory.CreatePropertyValue(p.GetValue(value), destructureObjects: true)));

        result = new StructureValue(members);
        return true;
    }
}
```

### BFF runtime-config endpoint
Single source of truth for all four frontend tools. Reads env vars, returns stable JSON, cacheable for 60 seconds.

```typescript
// apps/bff/src/routes/runtime-config.ts (Next.js App Router route handler)
import { NextResponse } from "next/server";

export const dynamic = "force-dynamic"; // computed per-request, cached at edge for 60s

type RuntimeConfig = {
  schemaVersion: 1;
  otel: {
    enabled: boolean;
    endpoint: string;          // OTel Collector OTLP HTTP receiver
    sampleRate: number;        // 0..1, applied per-trace at SDK
  };
  sentry: {
    enabled: boolean;
    dsn: string;
    environment: string;
    release: string;
    tracesSampleRate: number;  // applied via tracesSampler callback (mutable)
    errorsSampleRate: number;  // applied at init only — change requires re-init
  };
  posthog: {
    enabled: boolean;
    apiKey: string;
    host: string;              // self-hosted PostHog URL
    autocapture: boolean;
    sessionRecording: boolean; // recording sample rate is server-side per project
  };
  clarity: {
    enabled: boolean;
    projectId: string;         // empty string when disabled
  };
};

const env = (k: string, d = "") => process.env[k] ?? d;
const flag = (k: string, d: boolean) =>
  (process.env[k] ?? String(d)).toLowerCase() === "true";
const num = (k: string, d: number) => {
  const v = Number(process.env[k]);
  return Number.isFinite(v) ? v : d;
};

export async function GET() {
  const config: RuntimeConfig = {
    schemaVersion: 1,
    otel: {
      enabled:    flag("OTEL_ENABLED", true),
      endpoint:   env("OTEL_PUBLIC_ENDPOINT", ""),
      sampleRate: num("OTEL_SAMPLE_RATE", 0.1),
    },
    sentry: {
      enabled:           flag("SENTRY_ENABLED", true),
      dsn:               env("SENTRY_PUBLIC_DSN", ""),
      environment:       env("DEPLOYMENT_ENV", "dev"),
      release:           env("APP_RELEASE", "unknown"),
      tracesSampleRate:  num("SENTRY_TRACES_SAMPLE_RATE", 0.1),
      errorsSampleRate:  num("SENTRY_ERRORS_SAMPLE_RATE", 1.0),
    },
    posthog: {
      enabled:          flag("POSTHOG_ENABLED", true),
      apiKey:           env("POSTHOG_PUBLIC_KEY", ""),
      host:             env("POSTHOG_HOST", ""),
      autocapture:      flag("POSTHOG_AUTOCAPTURE", true),
      sessionRecording: flag("POSTHOG_SESSION_RECORDING", false),
    },
    clarity: {
      enabled:   flag("CLARITY_ENABLED", false),
      projectId: env("CLARITY_PROJECT_ID", ""),
    },
  };

  return NextResponse.json(config, {
    headers: { "Cache-Control": "public, max-age=60, s-maxage=60" },
  });
}
```

### Frontend init — Next.js portal (SSR-inlined config)
Server fetches the config during the root layout render and inlines it into the HTML so it's available before the first paint. No separate fetch on first load.

```tsx
// apps/portal/src/app/layout.tsx
import Script from "next/script";
import { headers } from "next/headers";
import { getRuntimeConfig } from "@/observability/runtime-config";
import { ObservabilityBootstrap } from "@/observability/bootstrap";

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  // Fetched server-side; falls back to all-disabled on error.
  const config = await getRuntimeConfig();

  return (
    <html>
      <head>
        {/* Inline config so client SDKs see it before any other JS runs. */}
        <script
          id="__runtime_config__"
          type="application/json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(config) }}
        />
        {/* Sentry MUST init synchronously to catch page-load errors. */}
        <ObservabilityBootstrap.SentryInline config={config} />
        {/* Clarity loads only when enabled — once loaded it stays loaded. */}
        {config.clarity.enabled && config.clarity.projectId && (
          <Script id="clarity" strategy="afterInteractive">{`
            (function(c,l,a,r,i,t,y){
              c[a]=c[a]||function(){(c[a].q=c[a].q||[]).push(arguments)};
              t=l.createElement(r);t.async=1;t.src="https://www.clarity.ms/tag/"+i;
              y=l.getElementsByTagName(r)[0];y.parentNode.insertBefore(t,y);
            })(window, document, "clarity", "script", "${config.clarity.projectId}");
          `}</Script>
        )}
      </head>
      <body>
        {/* OTel + PostHog can lazy-init after interactive. */}
        <ObservabilityBootstrap.LazyInit />
        {children}
      </body>
    </html>
  );
}
```

```typescript
// apps/portal/src/observability/runtime-config.ts
const DISABLED: RuntimeConfig = {
  schemaVersion: 1,
  otel:    { enabled: false, endpoint: "", sampleRate: 0 },
  sentry:  { enabled: false, dsn: "", environment: "", release: "", tracesSampleRate: 0, errorsSampleRate: 0 },
  posthog: { enabled: false, apiKey: "", host: "", autocapture: false, sessionRecording: false },
  clarity: { enabled: false, projectId: "" },
};

export async function getRuntimeConfig(): Promise<RuntimeConfig> {
  try {
    const r = await fetch(process.env.BFF_INTERNAL_URL + "/api/runtime-config",
                         { next: { revalidate: 60 } });
    if (!r.ok) return DISABLED;
    const cfg = await r.json();
    if (cfg?.schemaVersion !== 1) return DISABLED;   // schema mismatch → safe default
    return cfg as RuntimeConfig;
  } catch {
    return DISABLED;                                  // network/DNS/timeout → safe default
  }
}

// Mutable holder — samplers/callbacks read from here so we can update without re-init.
export const runtimeHolder: { current: RuntimeConfig } = { current: DISABLED };
```

```typescript
// apps/portal/src/observability/bootstrap.tsx — client-side SDK init
"use client";
import { useEffect } from "react";
import * as Sentry from "@sentry/nextjs";
import posthog from "posthog-js";
import { WebTracerProvider } from "@opentelemetry/sdk-trace-web";
import { ParentBasedSampler, Sampler, SamplingDecision, SamplingResult } from "@opentelemetry/sdk-trace-base";
import { Context, Link, SpanKind, Attributes } from "@opentelemetry/api";
import { runtimeHolder } from "./runtime-config";

// Custom sampler reads from holder per decision — workaround for OTel JS sampler being
// frozen at TracerProvider construction. shouldSample() is invoked per root span.
class RuntimeRatioSampler implements Sampler {
  shouldSample(_ctx: Context, traceId: string, _name: string, _kind: SpanKind,
               _attrs: Attributes, _links: Link[]): SamplingResult {
    const rate = runtimeHolder.current.otel.enabled ? runtimeHolder.current.otel.sampleRate : 0;
    // Deterministic on traceId (same trace samples consistently across browsers).
    const threshold = Math.floor(rate * 0xffffffff);
    const slice = parseInt(traceId.slice(0, 8), 16);
    return {
      decision: slice < threshold ? SamplingDecision.RECORD_AND_SAMPLED : SamplingDecision.NOT_RECORD,
    };
  }
  toString() { return "RuntimeRatioSampler"; }
}

function SentryInline({ config }: { config: RuntimeConfig }) {
  // Runs synchronously during HTML parse via dangerouslySetInnerHTML on the server,
  // OR effect on client. For brevity shown as effect here.
  if (!config.sentry.enabled || !config.sentry.dsn) return null;
  // tracesSampler callback reads holder so traces rate is mutable; errors rate is fixed at init.
  Sentry.init({
    dsn: config.sentry.dsn,
    environment: config.sentry.environment,
    release: config.sentry.release,
    sampleRate: config.sentry.errorsSampleRate, // errors — fixed at init (SDK limitation)
    tracesSampler: () => runtimeHolder.current.sentry.tracesSampleRate, // mutable
    beforeSend: (event) => piiScrub(event),
  });
  return null;
}

function LazyInit() {
  useEffect(() => {
    const raw = document.getElementById("__runtime_config__")?.textContent;
    const config = raw ? JSON.parse(raw) as RuntimeConfig : null;
    if (!config) return;
    runtimeHolder.current = config;

    // OTel JS — only init if enabled. Custom sampler keeps rate live-mutable.
    if (config.otel.enabled && config.otel.endpoint) {
      const provider = new WebTracerProvider({
        sampler: new ParentBasedSampler({ root: new RuntimeRatioSampler() }),
      });
      // ...register exporters/processors/instrumentations
      provider.register();
    }

    // PostHog — opt-in/out is the runtime toggle.
    if (config.posthog.enabled && config.posthog.apiKey) {
      posthog.init(config.posthog.apiKey, {
        api_host: config.posthog.host,
        autocapture: config.posthog.autocapture,
        disable_session_recording: !config.posthog.sessionRecording,
        loaded: (ph) => { if (!config.posthog.enabled) ph.opt_out_capturing(); },
      });
    }

    // Periodic refresh — pick up runtime changes without page reload.
    const id = setInterval(async () => {
      try {
        const r = await fetch("/api/runtime-config");
        if (!r.ok) return;
        const next = await r.json() as RuntimeConfig;
        if (next.schemaVersion !== 1) return;
        runtimeHolder.current = next;
        // PostHog: toggle without re-init
        if (next.posthog.enabled) posthog.opt_in_capturing();
        else                       posthog.opt_out_capturing();
        // PostHog autocapture toggle via set_config
        posthog.set_config({ autocapture: next.posthog.autocapture });
      } catch { /* swallow — keep last good config */ }
    }, 60_000);
    return () => clearInterval(id);
  }, []);
  return null;
}

export const ObservabilityBootstrap = { SentryInline, LazyInit };
```

### Frontend init — Vite admin SPA (fetched config)
No SSR. Bootstrap blocks app render until first config fetch resolves (with timeout → disabled fallback).

```typescript
// apps/admin/src/main.tsx
import { runtimeHolder, fetchConfigWithTimeout } from "./observability/runtime-config";
import { initSentryEarly, initOtelLazy, initPosthogLazy, loadClarityIfEnabled } from "./observability/init";

// Block the bundle entrypoint on a fast config fetch (1s timeout).
const config = await fetchConfigWithTimeout(1000);
runtimeHolder.current = config;

// Sentry first — synchronous, before any React renders.
initSentryEarly(config);

// React mounts now; OTel/PostHog/Clarity init after first interactive frame.
import("./bootstrap-react").then(({ mountReact }) => {
  mountReact();
  requestIdleCallback(() => {
    initOtelLazy(config);
    initPosthogLazy(config);
    loadClarityIfEnabled(config);
  });
});
```

```typescript
// apps/admin/src/observability/runtime-config.ts
export async function fetchConfigWithTimeout(ms: number): Promise<RuntimeConfig> {
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), ms);
  try {
    const r = await fetch("/api/runtime-config", { signal: ctrl.signal });
    if (!r.ok) return DISABLED;
    const cfg = await r.json();
    return cfg?.schemaVersion === 1 ? cfg : DISABLED;
  } catch {
    return DISABLED;
  } finally {
    clearTimeout(t);
  }
}
```

### Frontend init — React Native vendor app (cached config, applied next boot)
Mobile cannot apply config changes mid-session reliably (SDKs + bundled native code). Convention: fetch on app start, cache to `AsyncStorage`, **apply only on next boot**. Document this clearly to operators.

```typescript
// apps/mobile/src/observability/runtime-config.ts
import AsyncStorage from "@react-native-async-storage/async-storage";

const KEY = "obs:runtime-config:v1";

export async function bootRuntimeConfig(bffUrl: string): Promise<RuntimeConfig> {
  // 1. Load last-known-good from cache — applies for THIS session.
  const cached = await AsyncStorage.getItem(KEY);
  const applied = safeParse(cached) ?? DISABLED;

  // 2. Fetch fresh in the background — saved for NEXT boot only.
  fetch(`${bffUrl}/api/runtime-config`)
    .then(r => r.ok ? r.json() : null)
    .then(c => { if (c?.schemaVersion === 1) AsyncStorage.setItem(KEY, JSON.stringify(c)); })
    .catch(() => { /* keep last good */ });

  return applied;
}
```

### Backend — `ObservabilityOptions` + dynamic sampler + Serilog level switch
```csharp
// src/Service.Api/Observability/ObservabilityOptions.cs
public sealed record ObservabilityOptions
{
    public bool TracingEnabled { get; init; } = true;
    public double TraceSampleRate { get; init; } = 1.0;     // 0..1
    public bool MetricsEnabled { get; init; } = true;
    public string LogMinimumLevel { get; init; } = "Information"; // Verbose|Debug|Information|Warning|Error|Fatal
    public IReadOnlyList<string> AdditionalPiiDenyFields { get; init; } = [];
    public IReadOnlyList<string> PiiAllowFields { get; init; } = [];
}
```

```csharp
// src/Service.Api/Observability/RuntimeRatioSampler.cs
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

```csharp
// src/Service.Api/Program.cs — registration
builder.Services.AddOptions<ObservabilityOptions>()
    .Bind(builder.Configuration.GetSection("Observability"))
    .ValidateDataAnnotations();

// ConfigMap mount: /etc/config/observability.json — IOptionsMonitor watches it via file provider.
builder.Configuration.AddJsonFile("/etc/config/observability.json",
    optional: true, reloadOnChange: true);

builder.Services.AddSingleton<RuntimeRatioSampler>();

builder.Services.AddOpenTelemetry()
    .WithTracing(t => t
        .SetSampler(sp => sp.GetRequiredService<RuntimeRatioSampler>())
        // ... instrumentations + exporters
    );

// Serilog level switch — bound to IOptionsMonitor change callback.
var levelSwitch = new LoggingLevelSwitch(LogEventLevel.Information);
builder.Host.UseSerilog((ctx, sp, lc) =>
{
    var monitor = sp.GetRequiredService<IOptionsMonitor<ObservabilityOptions>>();
    levelSwitch.MinimumLevel = ParseLevel(monitor.CurrentValue.LogMinimumLevel);
    monitor.OnChange(o => levelSwitch.MinimumLevel = ParseLevel(o.LogMinimumLevel));

    lc.MinimumLevel.ControlledBy(levelSwitch)
      .Enrich.FromLogContext()
      .Enrich.WithSpan()
      .Destructure.With(new PiiDestructuringPolicy(monitor)) // monitor passed so deny-list updates live
      .WriteTo.OpenTelemetry(/* ... */);
});

static LogEventLevel ParseLevel(string s) =>
    Enum.TryParse<LogEventLevel>(s, true, out var l) ? l : LogEventLevel.Information;
```

The `PiiDestructuringPolicy` shown earlier takes `IOptions<PiiRedactionOptions>` — change its constructor to `IOptionsMonitor<ObservabilityOptions>` and read `CurrentValue.AdditionalPiiDenyFields` / `PiiAllowFields` on each `TryDestructure` call so deny-list edits apply without restart.

### `infra/observability/otel-collector-config.yaml` (canonical)
```yaml
# =============================================================================
# OTel Collector — canonical config. Pre-prod and prod render from this file.
# Deviations require an ADR.
#
# LOKI LABEL ALLOW-LIST: service, env, level
# NEVER add anything to this list without checking cardinality first.
# Each new label multiplies the index size; we have killed Loki ingesters at
# 3am over a single innocent-looking label. Trace/user/request IDs go IN the
# log line, not on it.
# =============================================================================

receivers:
  otlp:
    protocols:
      grpc: { endpoint: 0.0.0.0:4317 }
      http: { endpoint: 0.0.0.0:4318 }

processors:
  batch:
    timeout: 5s
    send_batch_size: 1000

  resourcedetection:
    detectors: [env, system]

  # PII backstop — services should redact in-process; this catches misses.
  attributes/pii:
    actions:
      - { key: password,        action: delete }
      - { key: token,           action: delete }
      - { key: authorization,   action: delete }
      - { key: api_key,         action: delete }
      - { key: email,           action: update, value: "[REDACTED]" }
      - { key: phone,           action: update, value: "[REDACTED]" }
      - { key: credit_card,     action: update, value: "[REDACTED]" }
      - { key: ssn,             action: update, value: "[REDACTED]" }

  # Tail sampling — uncomment when trace volume justifies the collector cost.
  # Keeps: all errors, all slow traces (>2s), 10% of normal traffic.
  # tail_sampling:
  #   decision_wait: 10s
  #   policies:
  #     - { name: errors,  type: status_code, status_code: { status_codes: [ERROR] } }
  #     - { name: slow,    type: latency,     latency: { threshold_ms: 2000 } }
  #     - { name: sample,  type: probabilistic, probabilistic: { sampling_percentage: 10 } }

exporters:
  otlp/jaeger:
    endpoint: jaeger-collector:4317
    tls: { insecure: true }

  prometheusremotewrite:
    endpoint: http://prometheus:9090/api/v1/write
    resource_to_telemetry_conversion: { enabled: true }

  loki:
    endpoint: http://loki:3100/loki/api/v1/push
    # Allow-list — see banner above. DO NOT EXTEND WITHOUT CARDINALITY REVIEW.
    default_labels_enabled:
      exporter: false
      job: false
    labels:
      attributes:
        service.name:          service
        deployment.environment: env
        level:                  level

service:
  pipelines:
    traces:
      receivers:  [otlp]
      processors: [resourcedetection, attributes/pii, batch]
      exporters:  [otlp/jaeger]
    metrics:
      receivers:  [otlp]
      processors: [resourcedetection, batch]
      exporters:  [prometheusremotewrite]
    logs:
      receivers:  [otlp]
      processors: [resourcedetection, attributes/pii, batch]
      exporters:  [loki]
```

## Operational Controls (incident runbook)
The knobs operators can change without redeploying. All env-var changes apply when the BFF / service ConfigMap is updated and reloaded — no pod restart needed.

| Knob | Where to change | Effect | Propagation time |
|---|---|---|---|
| Disable OTel JS (frontend) | BFF env `OTEL_ENABLED=false` | New page loads stop sending traces | ~60s (HTTP cache + holder refresh) |
| Drop OTel frontend sample rate | BFF env `OTEL_SAMPLE_RATE=0.01` | Reduces collector ingress from browsers | ~60s |
| Disable Sentry/GlitchTip frontend | BFF env `SENTRY_ENABLED=false` | New page loads skip Sentry init entirely | ~60s — **in-flight pages keep Sentry until reload** |
| Drop Sentry traces sample rate | BFF env `SENTRY_TRACES_SAMPLE_RATE=0.01` | `tracesSampler` reads new rate per transaction | ~60s, applies to in-flight pages |
| Change Sentry **errors** sample rate | BFF env `SENTRY_ERRORS_SAMPLE_RATE=0.5` | Only new page loads — SDK limitation | Next page load only |
| Disable PostHog | BFF env `POSTHOG_ENABLED=false` | `posthog.opt_out_capturing()` called on holder refresh | ~60s, applies to in-flight pages |
| Toggle PostHog autocapture | BFF env `POSTHOG_AUTOCAPTURE=false` | `posthog.set_config({autocapture:false})` | ~60s |
| Disable PostHog session recording | BFF env `POSTHOG_SESSION_RECORDING=false` | New sessions skip recording (existing recordings finish) | ~60s |
| Disable Microsoft Clarity | BFF env `CLARITY_ENABLED=false` | New page loads skip the Clarity script tag | Next page load only — once Clarity is loaded it stays loaded |
| Disable backend OTel tracing | Service ConfigMap `Observability.TracingEnabled=false` | `RuntimeRatioSampler` returns `Drop` for all spans | ~5s (ConfigMap reload + `IOptionsMonitor`) |
| Throttle backend trace sample rate | Service ConfigMap `Observability.TraceSampleRate=0.01` | Per-span sampling decision uses new rate | ~5s |
| Adjust Serilog minimum level | Service ConfigMap `Observability.LogMinimumLevel=Warning` | `LoggingLevelSwitch` applies live | ~5s |
| Update PII deny-list | Service ConfigMap `Observability.AdditionalPiiDenyFields=[...]` | Destructuring policy reads new list per log event | ~5s |
| Allow specific PII field for one service | Service ConfigMap `Observability.PiiAllowFields=["email"]` | Field passes through redaction in this service only | ~5s — **must have PR-justified reason** |
| Mobile app — any of the above | Same env vars on BFF | Cached in app on next start, **applied on next app boot** | Next cold start only — document in incident comms |

**Hard-down switch:** if everything must stop, set `OTEL_ENABLED=false`, `SENTRY_ENABLED=false`, `POSTHOG_ENABLED=false`, `CLARITY_ENABLED=false`, and `Observability.TracingEnabled=false` simultaneously. Logging continues at the configured level — to silence logs as well, set `LogMinimumLevel=Fatal`.

**What you cannot change at runtime** (would require redeploy):
* OTel Collector pipeline composition (receivers/processors/exporters) — that's deploy-time infra.
* Loki label allow-list — same reason.
* Sentry `errorsSampleRate` for in-flight browser sessions.
* Mobile app — anything for an in-flight session; only next boot.

### Future-proofing: swapping the config source
The runtime-config endpoint deliberately encapsulates "where the values come from." Today that's environment variables and ConfigMaps; later you may want a feature-flag service (PostHog feature flags, Unleash, OpenFeature) so config can be flipped from a UI with audit trail and per-tenant targeting. **No frontend or backend code changes are required** — only the BFF endpoint's implementation. Conceptually:

```typescript
// before:  return NextResponse.json(buildFromEnv());
// after:   return NextResponse.json(await flagClient.evaluateConfig(request.user));
```

Frontends still call `GET /api/runtime-config`, services still bind `ObservabilityOptions`. The contract is the JSON shape; the source is an implementation detail.

## When to Use
* Wiring a new service, BFF, or frontend for observability
* Adding a new background job, message consumer, or workflow that must be traceable end-to-end
* Reviewing a PR that adds logging, metrics, or error reporting
* Designing dashboards or alerts (label allow-list applies)
* Investigating a "missing trace" or "log not in Loki" incident

## When NOT to Use
* Application-specific business metric design — covered by `design-principles`
* Auth-related audit logging requirements — covered by `auth-patterns` (audit log is a separate stream)
* Frontend behavioural analytics (PostHog / Clarity) — different signal, different pipeline
* Synthetic monitoring / uptime probes — out of scope; handled by external tooling
