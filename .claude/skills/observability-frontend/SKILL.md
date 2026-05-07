---
name: observability-frontend
description: "Load when: instrumenting the customer portal (Next.js), admin SPA (Vite), or vendor mobile app (React Native + Expo) for observability. OTel JS / OTel RN, Sentry browser+RN (pointed at GlitchTip), PostHog, Clarity, BFF runtime-config endpoint + SSR-inlined / fetched / cached config, traceparent propagation, source-map upload, performance budgets. Read observability-contracts first."
---

# Observability — Frontend

## Purpose
Frontend implementation of the contracts in `observability-contracts`. Covers all three frontends — Next.js customer portal, Vite + React admin SPA, Expo React Native vendor app — plus the BFF's TypeScript `GET /api/runtime-config` endpoint that all three consume.

**Read `observability-contracts` first.** This skill assumes you know the runtime-config JSON shape (`schemaVersion: 1`), the SDK runtime-mutability matrix, the resource attribute schema, and the PII deny-list.

## Core Rules

### Per-Surface Init Strategy

| Surface | Config delivery | Sentry init timing | OTel/PostHog init timing | Clarity |
|---|---|---|---|---|
| Next.js portal | SSR-inlined as `<script type="application/json">` in `<head>` | Synchronous in `<head>` | `afterInteractive` | Conditional `<Script>` |
| Vite admin SPA | Fetched on bundle entry, **blocking with 1s timeout** | Synchronous, before React mounts | `requestIdleCallback` after first frame | Conditional script tag |
| Expo RN app | Fetched on app start, **cached in AsyncStorage**, applied **on next boot** | Synchronous in app entry | After first navigation frame | n/a |

**Rule**: Sentry/GlitchTip MUST init before any other JS that could throw — it's the safety net for page-load errors. OTel and PostHog can lazy-init.

### BFF Runtime-Config Endpoint
* Path: `GET /api/runtime-config`
* Reads env vars, returns the `RuntimeConfig` shape from `observability-contracts`.
* `Cache-Control: public, max-age=60, s-maxage=60`.
* On error/exception, return a fully-disabled config — never 5xx (a config outage must not break the frontend).

### Failure Mode Is OFF
Every frontend MUST default to all tools `enabled: false` when:
* The config fetch fails (network, DNS, timeout)
* Response is non-2xx
* JSON is malformed
* `schemaVersion !== 1`

A config outage degrades observability, never the user-facing app.

### Mutable Holder Pattern (the only way to live-tune SDKs)
OTel JS sampler is fixed at `TracerProvider` construction. Sentry `tracesSampleRate` is fixed at `Sentry.init`. The workaround for both: a single mutable holder object that custom samplers/callbacks read on each decision.

```ts
// shared mutable holder
export const runtimeHolder: { current: RuntimeConfig } = { current: DISABLED };
```

* OTel: implement a custom `Sampler` whose `shouldSample()` reads `runtimeHolder.current.otel.sampleRate`.
* Sentry: pass `tracesSampler: () => runtimeHolder.current.sentry.tracesSampleRate` (callback, not number).
* `sampleRate` for Sentry **errors** has no callback equivalent — it's frozen at init. Document this; rate changes require re-init or page reload.
* PostHog: `posthog.opt_in_capturing()` / `opt_out_capturing()` for runtime toggle; `posthog.set_config({autocapture})` for autocapture. Recording sample rate is server-side.
* Clarity: no runtime API once loaded — only conditional load.

### W3C Trace Context — browser to BFF
* OTel JS auto-instrumentation (`@opentelemetry/instrumentation-fetch` + `@opentelemetry/instrumentation-xml-http-request`) injects `traceparent` automatically on same-origin and configured cross-origin requests.
* `propagateTraceHeaderCorsUrls` MUST include the BFF origin or `traceparent` will be stripped by CORS preflight.
* For `next/link` SSR renders, the trace originates server-side — the `<head>` script that bootstraps the browser SDK should pick up `__NEXT_DATA__` for the existing `traceId` (the OTel Web SDK has no built-in mechanism for this; document that browser-side spans for the initial SSR navigation are independent traces).

### PII Redaction (frontend layer)
* **Sentry**: `beforeSend` hook applies the deny-list before the event leaves the browser.
* **PostHog**: `sanitize_properties` callback strips deny-listed keys from event properties.
* **OTel JS spans**: a `SpanProcessor.onStart` filter scrubs span attributes before export.
* Same canonical deny-list as `observability-contracts`. Per-frontend additions go through `runtimeHolder.current` if needed (rare — usually the deny-list is universal).

### Source Maps
Required for all three frontends. CI uploads to GlitchTip on every release using `sentry-cli`. Release identifier = `service.version` resource attr = `APP_RELEASE` env var. Same string in OTel and GlitchTip enables cross-pivot.

| Frontend | Build hook | Tool |
|---|---|---|
| Next.js portal | `next build` | `@sentry/nextjs` (auto) or manual `sentry-cli sourcemaps upload` |
| Vite admin SPA | post-build script | `@sentry/vite-plugin` |
| Expo RN | `eas build` | `@sentry/react-native` Expo config plugin |

### Performance Budget
Observability must not degrade UX. Hard rules:
* Sentry: lazy import non-error features. Errors-only mode (`integrations: []`) is < 30 KB gzipped.
* OTel JS: lazy-init after `afterInteractive` or `requestIdleCallback`. The `WebTracerProvider` + base instrumentations is ~50 KB gzipped — never block first paint on it.
* PostHog: `loaded` callback for any post-init logic; never `await` PostHog init in critical paths.
* In dev (`NODE_ENV !== 'production'`), default every tool to disabled unless explicitly enabled via `.env.local`. Avoids polluting production GlitchTip with developer noise.

## Patterns / Examples

### BFF runtime-config endpoint (Next.js App Router)
```typescript
// apps/bff/src/app/api/runtime-config/route.ts
import { NextResponse } from "next/server";

export const dynamic = "force-dynamic";

type RuntimeConfig = {
  schemaVersion: 1;
  otel:    { enabled: boolean; endpoint: string; sampleRate: number };
  sentry:  { enabled: boolean; dsn: string; environment: string; release: string;
             tracesSampleRate: number; errorsSampleRate: number };
  posthog: { enabled: boolean; apiKey: string; host: string;
             autocapture: boolean; sessionRecording: boolean };
  clarity: { enabled: boolean; projectId: string };
};

const env  = (k: string, d = "") => process.env[k] ?? d;
const flag = (k: string, d: boolean) => (process.env[k] ?? String(d)).toLowerCase() === "true";
const num  = (k: string, d: number) => { const v = Number(process.env[k]); return Number.isFinite(v) ? v : d; };

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

### Shared TypeScript types and holder
```typescript
// packages/observability-shared/src/types.ts
export type RuntimeConfig = { /* see contract */ };

export const DISABLED: RuntimeConfig = {
  schemaVersion: 1,
  otel:    { enabled: false, endpoint: "", sampleRate: 0 },
  sentry:  { enabled: false, dsn: "", environment: "", release: "",
             tracesSampleRate: 0, errorsSampleRate: 0 },
  posthog: { enabled: false, apiKey: "", host: "",
             autocapture: false, sessionRecording: false },
  clarity: { enabled: false, projectId: "" },
};

export const runtimeHolder: { current: RuntimeConfig } = { current: DISABLED };
```

### Next.js portal — SSR-inlined config
```tsx
// apps/portal/src/app/layout.tsx
import Script from "next/script";
import { getRuntimeConfig } from "@/observability/runtime-config";
import { ObservabilityBootstrap } from "@/observability/bootstrap";

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const config = await getRuntimeConfig();        // server-side fetch, falls back to DISABLED on error

  return (
    <html>
      <head>
        <script
          id="__runtime_config__"
          type="application/json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(config) }}
        />
        <ObservabilityBootstrap.SentryInline config={config} />
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
        <ObservabilityBootstrap.LazyInit />
        {children}
      </body>
    </html>
  );
}
```

```typescript
// apps/portal/src/observability/runtime-config.ts
import { DISABLED, RuntimeConfig } from "observability-shared";

export async function getRuntimeConfig(): Promise<RuntimeConfig> {
  try {
    const r = await fetch(process.env.BFF_INTERNAL_URL + "/api/runtime-config",
                         { next: { revalidate: 60 } });
    if (!r.ok) return DISABLED;
    const cfg = await r.json();
    if (cfg?.schemaVersion !== 1) return DISABLED;
    return cfg as RuntimeConfig;
  } catch {
    return DISABLED;
  }
}
```

### Next.js bootstrap — Sentry inline + lazy OTel/PostHog
```tsx
// apps/portal/src/observability/bootstrap.tsx
"use client";
import { useEffect } from "react";
import * as Sentry from "@sentry/nextjs";
import posthog from "posthog-js";
import { WebTracerProvider } from "@opentelemetry/sdk-trace-web";
import { ParentBasedSampler, Sampler, SamplingDecision, SamplingResult } from "@opentelemetry/sdk-trace-base";
import { Context, Link, SpanKind, Attributes } from "@opentelemetry/api";
import { runtimeHolder, RuntimeConfig } from "observability-shared";
import { piiScrub } from "./pii";

class RuntimeRatioSampler implements Sampler {
  shouldSample(_ctx: Context, traceId: string, _name: string, _kind: SpanKind,
               _attrs: Attributes, _links: Link[]): SamplingResult {
    const rate = runtimeHolder.current.otel.enabled ? runtimeHolder.current.otel.sampleRate : 0;
    const threshold = Math.floor(rate * 0xffffffff);
    const slice = parseInt(traceId.slice(0, 8), 16);
    return {
      decision: slice < threshold ? SamplingDecision.RECORD_AND_SAMPLED : SamplingDecision.NOT_RECORD,
    };
  }
  toString() { return "RuntimeRatioSampler"; }
}

function SentryInline({ config }: { config: RuntimeConfig }) {
  if (!config.sentry.enabled || !config.sentry.dsn) return null;
  Sentry.init({
    dsn: config.sentry.dsn,
    environment: config.sentry.environment,
    release: config.sentry.release,
    sampleRate: config.sentry.errorsSampleRate,                       // errors — frozen at init
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

    if (config.otel.enabled && config.otel.endpoint) {
      const provider = new WebTracerProvider({
        sampler: new ParentBasedSampler({ root: new RuntimeRatioSampler() }),
      });
      // ...register OTLP exporter, fetch + xhr instrumentations
      provider.register();
    }

    if (config.posthog.enabled && config.posthog.apiKey) {
      posthog.init(config.posthog.apiKey, {
        api_host: config.posthog.host,
        autocapture: config.posthog.autocapture,
        disable_session_recording: !config.posthog.sessionRecording,
        sanitize_properties: (props) => stripPii(props),
      });
    }

    // Refresh holder every 60s to pick up config changes without page reload.
    const id = setInterval(async () => {
      try {
        const r = await fetch("/api/runtime-config");
        if (!r.ok) return;
        const next = await r.json() as RuntimeConfig;
        if (next.schemaVersion !== 1) return;
        runtimeHolder.current = next;
        if (next.posthog.enabled) posthog.opt_in_capturing();
        else                       posthog.opt_out_capturing();
        posthog.set_config({ autocapture: next.posthog.autocapture });
      } catch { /* keep last good */ }
    }, 60_000);
    return () => clearInterval(id);
  }, []);
  return null;
}

export const ObservabilityBootstrap = { SentryInline, LazyInit };
```

### Vite admin SPA — fetched config, blocking on entry
```typescript
// apps/admin/src/main.tsx
import { runtimeHolder, DISABLED } from "observability-shared";
import { initSentryEarly, initOtelLazy, initPosthogLazy, loadClarityIfEnabled } from "./observability/init";

async function fetchConfigWithTimeout(ms: number) {
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

const config = await fetchConfigWithTimeout(1000);
runtimeHolder.current = config;

initSentryEarly(config);                    // synchronous, before React mounts

import("./bootstrap-react").then(({ mountReact }) => {
  mountReact();
  requestIdleCallback(() => {
    initOtelLazy(config);
    initPosthogLazy(config);
    loadClarityIfEnabled(config);
  });
});
```

### Expo RN — cached config, applied next boot
```typescript
// apps/mobile/src/observability/runtime-config.ts
import AsyncStorage from "@react-native-async-storage/async-storage";
import { DISABLED, RuntimeConfig } from "observability-shared";

const KEY = "obs:runtime-config:v1";

export async function bootRuntimeConfig(bffUrl: string): Promise<RuntimeConfig> {
  // 1. Load last-known-good — applies for THIS session.
  const cached = await AsyncStorage.getItem(KEY);
  const applied: RuntimeConfig = (() => {
    try {
      const parsed = cached ? JSON.parse(cached) : null;
      return parsed?.schemaVersion === 1 ? parsed : DISABLED;
    } catch { return DISABLED; }
  })();

  // 2. Fetch fresh in background — saved for NEXT boot only.
  fetch(`${bffUrl}/api/runtime-config`)
    .then(r => r.ok ? r.json() : null)
    .then(c => { if (c?.schemaVersion === 1) AsyncStorage.setItem(KEY, JSON.stringify(c)); })
    .catch(() => { /* keep last good */ });

  return applied;
}
```

```typescript
// apps/mobile/src/observability/init.ts (Expo + @sentry/react-native)
import * as Sentry from "@sentry/react-native";
import { runtimeHolder, RuntimeConfig } from "observability-shared";

export function initSentry(config: RuntimeConfig) {
  if (!config.sentry.enabled || !config.sentry.dsn) return;
  Sentry.init({
    dsn: config.sentry.dsn,
    environment: config.sentry.environment,
    release: config.sentry.release,
    sampleRate: config.sentry.errorsSampleRate,
    tracesSampler: () => runtimeHolder.current.sentry.tracesSampleRate,
    beforeSend: (event) => piiScrub(event),
  });
}
// OTel for RN: use @opentelemetry/sdk-trace-base + a fetch instrumentation.
// @opentelemetry/sdk-trace-web is incompatible with RN — do NOT import it.
```

### PII scrubber (Sentry `beforeSend`)
```typescript
// packages/observability-shared/src/pii.ts
const DENY = new Set([
  "password","passwd","pwd","secret","token","api_key","apikey","authorization",
  "ssn","sin","tax_id","national_id","email","email_address","phone","phone_number",
  "mobile","credit_card","card_number","cvv","pan","date_of_birth","dob",
  "address","street","postal_code","zip","ip_address","ip",
]);

function scrubObject(obj: Record<string, any> | undefined): Record<string, any> | undefined {
  if (!obj) return obj;
  const out: Record<string, any> = {};
  for (const [k, v] of Object.entries(obj)) {
    out[k] = DENY.has(k.toLowerCase()) ? "[REDACTED]"
           : (v && typeof v === "object" && !Array.isArray(v)) ? scrubObject(v) : v;
  }
  return out;
}

export function piiScrub<T extends { extra?: any; tags?: any; user?: any; request?: any }>(event: T): T {
  event.extra   = scrubObject(event.extra);
  event.tags    = scrubObject(event.tags);
  event.user    = scrubObject(event.user);
  event.request = scrubObject(event.request);
  return event;
}

export function stripPii(props: Record<string, any>): Record<string, any> {
  return scrubObject(props) ?? {};
}
```

## Operational Controls (frontend knobs)
All apply by changing BFF env vars, with the propagation rules below.

| Knob | Effect | Propagation |
|---|---|---|
| `OTEL_ENABLED=false` | New page loads stop sending traces; in-flight pages stop on next holder refresh | ~60s |
| `OTEL_SAMPLE_RATE=0.01` | `RuntimeRatioSampler` reads new rate per decision | ~60s, applies in-flight |
| `SENTRY_ENABLED=false` | New page loads skip Sentry init | ~60s — **in-flight pages keep Sentry until reload** |
| `SENTRY_TRACES_SAMPLE_RATE=0.01` | `tracesSampler` callback reads new value per transaction | ~60s, applies in-flight |
| `SENTRY_ERRORS_SAMPLE_RATE=0.5` | Only new page loads — SDK limitation | Next page load |
| `POSTHOG_ENABLED=false` | `posthog.opt_out_capturing()` called on holder refresh | ~60s, applies in-flight |
| `POSTHOG_AUTOCAPTURE=false` | `posthog.set_config({autocapture:false})` | ~60s |
| `POSTHOG_SESSION_RECORDING=false` | New sessions skip recording (existing finish) | ~60s |
| `CLARITY_ENABLED=false` | New page loads skip the Clarity script tag | Next page load — once loaded, Clarity stays loaded |
| **Mobile app — any of the above** | Cached, applied on **next app boot** | Next cold start only |

**Hard-down switch**: set `OTEL_ENABLED=false`, `SENTRY_ENABLED=false`, `POSTHOG_ENABLED=false`, `CLARITY_ENABLED=false` simultaneously.

## Future-Proofing
The runtime-config endpoint encapsulates "where the values come from." Today it's env vars; tomorrow it could be a feature-flag service (PostHog feature flags, Unleash, OpenFeature) for per-tenant targeting and audit trail. **No frontend code changes required** — only the BFF endpoint's implementation. Frontends still call `GET /api/runtime-config`; the contract is the JSON shape.

```typescript
// before:  return NextResponse.json(buildFromEnv());
// after:   return NextResponse.json(await flagClient.evaluateConfig(request.user));
```

## When to Use
* Wiring a new frontend (or a new page route) for observability
* Adding/changing the BFF runtime-config endpoint
* Reviewing a frontend PR that adds Sentry/PostHog/OTel/Clarity calls
* Investigating "errors not in GlitchTip" or "events not in PostHog" from a browser/mobile session

## When NOT to Use
* Backend instrumentation (.NET services, Wolverine, Hangfire) — see `observability-backend`
* OTel Collector / Loki / Jaeger / Prometheus / GlitchTip deployment — see `observability-infra`
* Defining new contracts (runtime-config schema, deny-list, resource attrs) — see `observability-contracts`, requires ADR
* Behavioural analytics event taxonomy — different concern
