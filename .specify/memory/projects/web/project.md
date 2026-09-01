# customer-portal (web)

| Field | Value |
|---|---|
| Surface | `web` |
| Workspace | TAGIN-PLATFORM |
| Type | Frontend — `nextjs` |
| App | `customer-portal` |
| Code Root | `src/frontend/apps/customer-portal` |
| Architecture Pattern | Next.js App Router (Server/Client component boundary) |

## Responsibility
Public-facing customer web portal. SEO-driven pages, Strapi v5 CMS content,
Cloudflare R2 image delivery, NextAuth v5 (Keycloak) sessions.

## Toolchain
| | |
|---|---|
| Package manager | pnpm (workspace) |
| Build | `pnpm -F customer-portal build` |
| Test | `pnpm -F customer-portal test` |
| Lint | `pnpm -F customer-portal lint` |

## Always-load skill packs
> The single source of truth for which frontend skills load for this surface.
> Read by the shared surface-resolution preamble; every command uses this list.

**Always:**
- `nextjs-patterns`
- `react-component-patterns`
- `frontend-design-system`
- `accessibility-standards` (core + web-DOM appendix)
- `observability-frontend`

**Keyword overlays (add when the story matches):**
- `state`, `zustand`, `store` → `zustand-state-management`
- `auth`, `login`, `session`, `permission` → `authorization-patterns` (claim contract; see `.specify/memory/auth_contract.md`)
- `file`, `upload`, `image`, `attachment` → `file-pipeline-patterns`

## Memory Files
- [tech-stack.md](./tech-stack.md)
- [coding-standards.md](./coding-standards.md)

## Notes
Auth mechanics (NextAuth v5 provider, session shape) live in `nextjs-patterns`
+ `.specify/memory/auth_contract.md` (`PortalSession`). Do not hardcode session
claims in skills.
