# TAGIN-PLATFORM — Project Router

Workspace memory index. Each project owns an isolated memory folder under
`projects/{surface}/`. A command resolves the **active surface**, reads this
index + shared `standards/`, then reads **only** that one surface's folder.

`surface` is the stable key (`backend | web | admin | mobile`) that
`active_surface` in `session.yaml` routes on. `type` is the stack family used
by the surface-resolution preamble to pick the code root, standards overlay,
and always-load skill packs.

Frontend surfaces: 3  (Web: 1 · Admin: 1 · Mobile: 1)

> Scope: **frontend surfaces only**. Backend is out of scope for this manifest.

| surface | one-line | app | type | code root |
|---|---|---|---|---|
| `web` | Customer portal (public web) | `customer-portal` | `nextjs` | `src/frontend/apps/customer-portal` |
| `admin` | Internal admin console | `tagin-console` | `nextjs` | `src/frontend/apps/tagin-console` |
| `mobile` | Vendor mobile app | `vendor-app` | `rn-expo` | `src/frontend/apps/vendor-app` |

> **Stack note.** `web` and `admin` are **both Next.js** — there is no
> React+Vite+Tanstack SPA in this workspace. `admin` is a Next.js console that
> loads `nextjs-patterns` **plus** the `nextjs-admin-patterns` overlay (dense
> data tables, RBAC-gated UI, bulk actions). The retired `react-admin-patterns`
> skill (Vite/Tanstack) does not apply to any app here.

## Shared libraries (`src/frontend/packages/`)

Monorepo shared code is declared as libraries (path + consuming surfaces), not
as a surface. A story changing a library lands in the owning surface's branch;
the workspace runner (pnpm `-F` + Turbo) rebuilds dependents.

| library | consumers | notes |
|---|---|---|
| `api-client` | web, admin, mobile | generated from `contracts/api-spec.json` |
| `ui-kit` | web, admin | shared shadcn/ui + Tailwind primitives (web only) |
| `shared-types` | web, admin, mobile | cross-surface TS types |

Workspace runner: **pnpm workspaces + Turbo** (`src/frontend/turbo.json`).
