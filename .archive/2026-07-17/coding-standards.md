# backend — Coding Standards

Overlay on shared `standards/coding-standards.md`. Stack-specific rules only.

## Formatter / Linter
`dotnet format` + EditorConfig. `sk.implement` runs it after each task phase.

## Conventions
- Target the seams, never the backing library (see CLAUDE.md STACK NOTE + `backend-architecture`).
- `Result<T>`/`Error` for expected failures; exceptions for bugs/infrastructure only.
- Command → single aggregate; cross-aggregate via domain/integration events.
- Idempotency: `commandId` (handler) + HTTP Idempotency-Key (API) both required.

## Architecture Rules
- Clean Architecture layer boundaries enforced by NetArchTest invariants (`backend-architecture`).
- Library names live only in `infrastructure-wiring`; `backend-architecture` is the canonical SSOT.
