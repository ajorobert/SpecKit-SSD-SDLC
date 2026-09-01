# customer-portal — Tech Stack

| Field | Value |
|---|---|
| Type | Frontend — `nextjs` |
| Framework | Next.js (App Router) 15+ · React 19 |
| Auth | NextAuth v5 (Keycloak provider) |
| CMS | Strapi v5 (Document Service) |
| Images | Cloudflare R2 |
| Styling | Tailwind v4 (CSS-first) + shadcn/ui + CVA |
| State | Zustand v5 (client UI state) · TanStack Query (server state) |

> Version specifics marked here reflect the framework's assumed stack. Confirm
> exact versions against `src/frontend/apps/customer-portal/package.json` in the
> real TAGIN-PLATFORM workspace (not present in the framework checkout) — or let
> `sk.init` fill them.

## Stack Detail
- **Rendering:** Server/Client component boundary; SSR + ISR with tag
  invalidation; Server Actions. SEO-first (metadata, sitemap).
- **Data:** backend fetch contract (traceparent + bearer + Idempotency-Key) —
  owned by `nextjs-patterns`.
- **UI layer:** Tailwind v4 + shadcn/ui (`frontend-design-system`);
  decomposition + forms (`react-component-patterns`); WCAG
  (`accessibility-standards`).
- **Observability:** OTel JS, Sentry→GlitchTip, PostHog (anonymous), Microsoft
  Clarity (web only) — `observability-frontend`.
