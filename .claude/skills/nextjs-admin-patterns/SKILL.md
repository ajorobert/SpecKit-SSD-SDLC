---
name: nextjs-admin-patterns
description: "Load when: implementing or reviewing the internal admin console (tagin-console) — a Next.js App Router app. Admin-specific overlay ON TOP of nextjs-patterns: auth-gated console route groups, RSC-rendered dense data tables, server-action bulk operations, RBAC-driven UI gating, audit-heavy forms, admin error/permission taxonomy, re-render hygiene for interactive grids, bundle discipline, and view transitions. Base App Router / session / backend fetch contract come from nextjs-patterns and are not restated here."
when_to_load:
  - Any admin-console route group, layout, or feature module (tagin-console)
  - Dense data-table / data-grid work (sorting, filtering, pagination, bulk selection)
  - Server-action bulk operations (activate/deactivate/assign across many rows)
  - RBAC-driven UI gating (permission-conditional actions, columns, routes)
  - Audit-heavy admin forms and confirmation flows
  - Re-render / bundle review on an interactive client grid in the console
references:
  - .specify/memory/auth_contract.md
  - .specify/memory/projects/admin/project.md
---

# Next.js Admin Console Patterns (overlay on nextjs-patterns)

## 1. Purpose
Production patterns for the **internal admin console** (`tagin-console`) built on
**Next.js App Router** — the same base stack as the customer portal. This skill
is an **overlay**: it assumes `nextjs-patterns` is loaded and covers only what is
*distinct about an admin console* — dense data tables, bulk operations,
RBAC-gated UI, audit-heavy forms, and the admin error/permission taxonomy.

**This is Next.js, not a Vite/Tanstack-Router SPA.** The retired
`react-admin-patterns` skill described a React+Vite admin SPA that does not exist
in this workspace. Do not apply Vite, Tanstack Router file routes,
`createFileRoute`, `keycloak-js`, or `import.meta.env` here.

Excludes (owned elsewhere, do not restate):
- App Router route organisation, Server/Client boundary, SSR/streaming, Server
  Actions basics, NextAuth v5 (Keycloak) session, and the **backend fetch
  contract** (traceparent + bearer + Idempotency-Key) → `nextjs-patterns`.
- Component decomposition, prop typing, forms, hooks → `react-component-patterns`.
- Tailwind v4 / shadcn / tokens / dark mode → `frontend-design-system`.
- WCAG rules → `accessibility-standards`. Store design → `zustand-state-management`.
- Telemetry emission internals / PII deny-list → `observability-frontend`.

## 2. Core Rules

### 2.1 Console structure & auth-gated route groups
- The whole console lives behind auth. Use a Next.js **route group** with a
  layout guard: `app/(console)/layout.tsx` reads the server session
  (`nextjs-patterns` session helper) and redirects unauthenticated users to
  login. No console page renders for an unauthenticated request.
- Feature-first layout under the group:
  ```
  app/(console)/
  ├── layout.tsx              # AUTH gate (server session) + console chrome
  ├── page.tsx               # dashboard landing
  └── listings/
      ├── page.tsx           # RSC list (server-fetched table data)
      ├── [id]/page.tsx      # RSC detail
      └── _components/       # client islands: interactive grid, bulk bar, filters
  features/listings/
  ├── actions.ts             # 'use server' actions (mutations, bulk ops)
  ├── columns.tsx            # table column defs
  └── types.ts
  ```
- **Never gate the console with client-only checks alone.** The layout server
  guard is the boundary; client `useSession`-style hiding is UX, not security —
  the backend re-authorizes every request.

### 2.2 Data tables — RSC first, client island for interaction
Admin screens are table-dense. Default to **server-rendered tables**; add a
client island only for genuine interactivity.

- **Initial data is fetched in the RSC** (`page.tsx`) via the `nextjs-patterns`
  server fetch wrapper and passed to a table component. First paint needs no
  client fetch and no spinner.
- **Interactive behaviour** (column sort, multi-select, inline row actions) lives
  in a `"use client"` island under `_components/`. If the island refetches on
  filter/sort/pagination, it uses **TanStack Query** with typed query-key
  constants — never `useEffect + fetch`, never a second bespoke fetch path.
  (This mirrors the portal's client-data rule in `nextjs-patterns`.)
- **Server-driven pagination/filter** is preferred for large sets: encode
  page/sort/filter in the URL search params, let the RSC read them and refetch.
  `searchParams` in → server fetch → new table. Client island only manages
  selection and optimistic affordances.
- **Column definitions are typed constants** in `features/{feature}/columns.tsx`;
  never inline column arrays at the call site.

### 2.3 Bulk operations via Server Actions
Bulk activate/deactivate/assign is the defining admin mutation.

- Implement bulk mutations as **Server Actions** (`'use server'` in
  `features/{feature}/actions.ts`), invoked from the client bulk bar.
- **Idempotency:** each bulk submit carries one stable `Idempotency-Key` per user
  action (not per row, not per retry). Server Action forwards it through the
  backend fetch contract (owned by `nextjs-patterns`). A retried submit must not
  double-apply.
- **Partial failure is normal at scale:** the action returns a per-item result
  ({ id, ok, error }[]); the UI reports "N succeeded, M failed" and lets the user
  retry only the failures. Never present a bulk op as all-or-nothing unless the
  backend is transactional.
- **Revalidate after mutation:** call `revalidatePath`/`revalidateTag` for the
  affected list so the RSC table reflects the change; if a client island holds
  the data, invalidate its query key prefix instead.
- Confirm destructive bulk actions with an explicit dialog stating the count and
  the effect. // AUTH: assume the action re-checks permission server-side.

### 2.4 RBAC-driven UI gating
- Read the user's roles/permissions from the **server session** (shape defined in
  `.specify/memory/auth_contract.md` → `AdminSession`; do not hardcode claim
  names here).
- Gate **actions, columns, and routes** by permission: a user without
  `listings:write` sees the table read-only (no row actions, no bulk bar); a user
  without access to a route is redirected by the group layout guard.
- **UI gating is never the security control.** Hiding a button is UX; the backend
  authorizes every mutation. The claim/permission contract itself is owned by
  `authorization-patterns` — reference it, don't restate it.

### 2.5 Audit-heavy forms
- Admin forms frequently change other users' data — treat them as audited
  operations. Compose forms per `react-component-patterns` (react-hook-form +
  Zod); this section only adds admin obligations:
  - **Show before/after** for consequential edits where feasible (status changes,
    role changes) so the operator sees what they are changing.
  - **Reason/justification field** on sensitive mutations when the backend audit
    log expects it (check the endpoint contract).
  - **Confirm irreversible actions** with a typed confirmation, not a bare OK.

### 2.6 Re-render hygiene (interactive grids)
Re-render bugs in admin tables come from over-subscription and unstable refs.
Store-selector rules are owned by `zustand-state-management`; this is grid-local:
- **TanStack Query `select`** to subscribe to the rendered slice, not the whole
  row set. **`useMemo` column defs**; **`useCallback`** row-action handlers passed
  to memoised rows.
- **`React.memo` at meaningful boundaries only** — list rows, chart wrappers,
  toolbars. Wrapping every leaf is anti-value.
- **No new object/array literals in JSX** for props consumed by memoised rows.
- Read URL state with a selector where possible; avoid subscribing a whole grid
  to every search-param change.

### 2.7 Bundle discipline
- **Route-level code splitting is automatic** in the App Router — do not fight it
  with eager cross-route imports.
- **`next/dynamic`** (with `ssr:false` where appropriate) for heavy admin-only
  widgets: data-grid virtualisation, charts, rich-text editors, PDF/CSV export,
  map pickers. Anything > ~50 KB not on first paint.
- **Named subpath imports** (`lucide-react`, `date-fns`, `lodash-es`) — never
  barrel or default-namespace imports that break tree-shaking.

### 2.8 Error & permission taxonomy
Distinguish the four cases; only genuine failures reach an error boundary.
- **Render errors** → nearest `error.tsx` (route segment) / root `error.tsx`.
  Every console segment declares one.
- **401 auth-expired** → handled by the `nextjs-patterns` session/fetch layer
  (silent refresh or redirect). Never reaches an error boundary.
- **403 forbidden** → expected; render inline "you don't have access", not a
  boundary.
- **Validation (4xx w/ field errors)** → inline on the form, not a boundary.

### 2.9 View transitions
- Use App Router view transitions for spatial continuity on list → detail →
  list and sibling tab switches; not for background refreshes or filter changes
  that don't change route shape.
- Respect `prefers-reduced-motion` (global CSS disables the transition group).
  Keep transitions ≤ 300 ms.

## 3. Comment markers

### Owned by this skill
_None._ The admin overlay emits markers owned by its base + cross-cutting skills,
all of which are co-loaded on this surface (see `projects/admin/project.md`).

### Used but not owned
| Marker | Owner | Where it appears here |
|---|---|---|
| `// FETCH:` | `nextjs-patterns` (base, always co-loaded on admin) | Server/client fetch to backend (§2.2, §2.3) |
| `// AUTH:` | `authorization-patterns` | Route-group guard, RBAC gates, bulk/audit actions (§2.1, §2.3, §2.4) |
| `// IDEMPOTENCY:` | `backend-feature-patterns` | Bulk Server Action supplying `Idempotency-Key` (§2.3) |
| `// EVENT:` | `observability-frontend` | Admin action success branches, bulk submits (§4) |
| `// CONSENT:` | `observability-frontend` | Analytics gate at console root layout (§4) |
| `// MASK:` | `observability-frontend` | Recognised but **NOT emitted** on admin — Clarity is web-only (§4) |

## 4. Observability on the admin surface
Marker landing zone only — emission internals, SDK init, and the PII deny-list
live in `observability-frontend`.
- **`// CONSENT:`** at the console root layout before any analytics SDK starts
  (internal-tool consent is a one-time policy acceptance, but the gate exists).
- **`// EVENT:`** on meaningful admin actions: mutation success, filter apply,
  bulk-operation submit. PostHog is the sink; pre-consent events are dropped.
- **`// MASK:` is NOT emitted on admin.** Microsoft Clarity is disabled on this
  surface (Clarity runs on the customer portal only), so the PII-redaction
  obligation `// MASK:` represents does not apply here.
- **Error boundary integration:** every `error.tsx` reports the caught error to
  the sink once, with the route path as context.

## 5. When to use
- Any `tagin-console` admin route group, layout, or feature module (Next.js).
- Data-table, bulk-operation, RBAC-gating, and audit-form design for the console.
- Re-render / bundle review on an interactive console grid.

## 6. When NOT to use
- **Customer portal** public web (Next.js) — base patterns are the same, but
  SEO/ISR/Strapi/public-consent belong to `nextjs-patterns`; load this overlay
  only for the console.
- **Mobile app** (React Native + Expo) — see `react-native-patterns`.
- **Base App Router / session / fetch contract** — see `nextjs-patterns`
  (this overlay assumes it and never restates it).
- **Component decomposition, forms, hooks** — `react-component-patterns`.
- **Tailwind/shadcn/tokens** — `frontend-design-system`. **WCAG** —
  `accessibility-standards`. **Stores** — `zustand-state-management`.
