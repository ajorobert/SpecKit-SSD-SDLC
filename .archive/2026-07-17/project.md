# backend

| Field | Value |
|---|---|
| Surface | `backend` |
| Workspace | TAGIN-PLATFORM |
| Type | Backend — `dotnet` |
| Code Root | `src/backend` |
| Architecture Pattern | Clean Architecture + seam architecture (.NET 10) |

## Responsibility
REST API + background workers. Seam-targeted (`IAppCommandBus`/`IAppQueryBus`,
`Result<T>`/`Error`, repositories, `HybridCache`, `IUserContext`). See
`backend-architecture` (canonical SSOT).

## Toolchain
| | |
|---|---|
| Build | `dotnet build` |
| Test | `dotnet test` |
| Lint/format | `dotnet format` |

## Always-load skill packs
**Always:** `backend-architecture` (SSOT), `backend-feature-patterns`.
**Keyword overlays:** per `sk.codegen` backend keyword map (api-endpoint,
orchestration, authorization, data-access, caching, search, file-pipeline,
integration-adapter, feature-management, infrastructure-wiring).

## Memory Files
- [tech-stack.md](./tech-stack.md)
- [coding-standards.md](./coding-standards.md)

## Notes
Backend pack selection is unchanged by the frontend alignment work; listed here
so the manifest is complete and the surface-resolution preamble is uniform.
