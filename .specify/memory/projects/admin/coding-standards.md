# tagin-console — Coding Standards

Overlay on shared `standards/coding-standards.md`. Stack-specific rules only.

## Formatter / Linter
Prettier + ESLint (Next.js config). `sk.implement` runs `pnpm -F tagin-console lint --fix` after each task phase.

## Conventions
- Server Components by default; RSC-render data tables; `"use client"` only for interactive grid/bulk-action controls.
- All console routes are auth-gated (route-group layout guard) — no unauthenticated console surface.
- RBAC-driven UI: gate actions/columns by permission per `nextjs-admin-patterns`; never rely on hiding alone — the backend enforces authorization.
- Data fetching via the `nextjs-patterns` fetch wrapper (traceparent + Idempotency-Key); bulk actions are idempotent.
- DTOs match `contracts/api-spec.json` exactly — no `any`.

## Architecture Rules
- Console-specific patterns (dense tables, bulk actions, audit forms) per `nextjs-admin-patterns` (overlay on `nextjs-patterns`).
- Component decomposition per `react-component-patterns`.
- WCAG 2.2 AA per `accessibility-standards` — data grids need accessible headers, sort, and keyboard navigation.
- Observability: no Microsoft Clarity on admin.
