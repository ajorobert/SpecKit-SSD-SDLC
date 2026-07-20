# customer-portal — Coding Standards

Overlay on shared `standards/coding-standards.md`. Stack-specific rules only.

## Formatter / Linter
Prettier + ESLint (Next.js config). `sk.implement` runs `pnpm -F customer-portal lint --fix` after each task phase.

## Conventions
- Server Components by default; add `"use client"` only when interactivity/state requires it.
- No secrets in Client Components or `NEXT_PUBLIC_*` beyond intended public config.
- Data fetching goes through the fetch wrapper owned by `nextjs-patterns` (traceparent + Idempotency-Key) — never raw `fetch` to the backend.
- Design tokens via `frontend-design-system`; no ad-hoc hex/px.
- DTOs match `contracts/api-spec.json` exactly — no `any`.

## Architecture Rules
- App Router route organisation per `nextjs-patterns`.
- Component decomposition per `react-component-patterns`; forms via react-hook-form + Zod.
- WCAG 2.2 AA per `accessibility-standards`; blocking a11y issue = not shippable.
