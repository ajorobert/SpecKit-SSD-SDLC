# tagin-console — Tech Stack

| Field | Value |
|---|---|
| Type | Frontend — `nextjs` |
| Framework | Next.js (App Router) 15+ · React 19 |
| Auth | NextAuth v5 (Keycloak provider) — same family as web |
| CMS | none (internal console) |
| Styling | Tailwind v4 (CSS-first) + shadcn/ui + CVA |
| State | Zustand v5 (client UI state) · TanStack Query (server state) |
| Tables | TanStack Table (dense data grids) |

> **This is Next.js, not React+Vite+Tanstack Router.** The framework previously
> assumed a Vite SPA for admin; that is a mismatch and `react-admin-patterns`
> has been retired in favour of the `nextjs-admin-patterns` overlay. Confirm
> exact versions against `src/frontend/apps/tagin-console/package.json`.

## Stack Detail
- **Rendering:** auth-gated route groups; RSC-rendered data tables; Server
  Actions for mutations/bulk operations. No public SEO surface, no ISR/Strapi.
- **Console patterns:** dense data grids, bulk actions, RBAC-driven UI gating,
  audit-heavy forms — owned by `nextjs-admin-patterns` (overlay on
  `nextjs-patterns`).
- **Data:** backend fetch contract (traceparent + bearer + Idempotency-Key) —
  reused from `nextjs-patterns`.
- **Observability:** OTel JS, Sentry→GlitchTip, PostHog (anonymous). **No
  Microsoft Clarity on admin** — `observability-frontend`.
