# tagin-console (admin)

| Field | Value |
|---|---|
| Surface | `admin` |
| Workspace | TAGIN-PLATFORM |
| Type | Frontend — `nextjs` |
| App | `tagin-console` |
| Code Root | `src/frontend/apps/tagin-console` |
| Architecture Pattern | Next.js App Router (auth-gated console; RSC data tables) |

## Responsibility
Internal admin/operations console. **Next.js — not React+Vite+Tanstack.**
Auth-gated route groups, dense data tables, bulk actions, RBAC-driven UI
gating, audit-heavy forms. No public SEO surface; no Strapi CMS.

## Toolchain
| | |
|---|---|
| Package manager | pnpm (workspace) |
| Build | `pnpm -F tagin-console build` |
| Test | `pnpm -F tagin-console test` |
| Lint | `pnpm -F tagin-console lint` |

## Always-load skill packs
> The single source of truth for which frontend skills load for this surface.
> Read by the shared surface-resolution preamble; every command uses this list.

**Always:**
- `nextjs-patterns` (base — App Router, fetch contract, session)
- `nextjs-admin-patterns` (overlay — console-specific: data tables, bulk actions, RBAC-gated UI)
- `react-component-patterns`
- `frontend-design-system`
- `accessibility-standards` (core + web-DOM appendix)
- `observability-frontend` (policy: **no Microsoft Clarity on admin**)

**Keyword overlays (add when the story matches):**
- `state`, `zustand`, `store` → `zustand-state-management`
- `auth`, `login`, `session`, `permission` → `authorization-patterns` (claim contract; see `.specify/memory/auth_contract.md`)
- `file`, `upload`, `image`, `attachment` → `file-pipeline-patterns`

## Memory Files
- [tech-stack.md](./tech-stack.md)
- [coding-standards.md](./coding-standards.md)

## Notes
Session model is Next.js/NextAuth v5 (Keycloak) — same family as `web`, **not**
keycloak-js in-memory + `prompt=none`. Session shape (`AdminSession`) lives in
`.specify/memory/auth_contract.md`.
