# Shared: Surface Resolution Preamble

**Single source of truth for "which frontend surface am I working on, where does
its code live, and which skill packs load."** Every frontend-touching command
references this instead of hardcoding its own per-surface branch. Injecting it
as a stable `inject_files` context keeps prompt-cache hits. (Scope: frontend
surfaces only — `web | admin | mobile`.)

> Why this exists: previously each command (`sk.codegen`, `sk.scaffolding`,
> `sk.review`, `sk.uat`, `sk.testproject`, `sk.perf`, `sk.refactor`,
> `sk.verify`) hardcoded its own load list. They drifted — observability was
> missing everywhere, mobile was under-loaded, and generate-time ≠ review-time
> rule-sets. This file makes pack selection **data** (in the manifest), read
> identically everywhere.

## Step 1 — Resolve the active surface

Determine the frontend surface `∈ web | admin | mobile` from the signals the
command already has (this replaces each command's hardcoded per-surface branch —
no new session field is required):

1. If the caller passed a `{Project}`/`{ProjectType}` (e.g. `sk.implementproject`) → map the project → surface via `.specify/memory/projects/index.md`.
2. Else derive from the unit-brief **Impacted Projects** / story frontmatter: the single impacted frontend project's row in `index.md`.
3. If ambiguous between two frontends → stop and ask; **never guess** between `web` and `admin` (both Next.js) or across surfaces.

(Backend work is out of scope for this preamble — it keeps its existing pack
selection.)

## Step 2 — Read the manifest for that surface

From `.specify/memory/projects/index.md` get the surface's **code root** and **type**. Then read **only** that surface's folder:

- `.specify/memory/projects/{surface}/project.md` — code root, toolchain (build/test/lint), and the **Always-load skill packs** list.
- `.specify/memory/projects/{surface}/tech-stack.md` and `coding-standards.md` — the per-surface overlay on shared `standards/`.

Operate on files only within the resolved **code root**.

## Step 3 — Load the packs

Load the surface's **Always** packs verbatim from its `project.md`, then add any
**keyword overlay** packs whose triggers match the story keywords. Respect
`Never load on this surface` exclusions. **Load ≤6 packs total** — prioritise
specialist packs when the cap is reached.

This list is **identical across every command** for a given surface — that is
the point. Do not re-derive or supplement it from prose.

Also load `.claude/skills/shared/frontend-markers.md` — the frontend-reachable
comment-marker index — so marker contracts (`// FETCH:`, `// EVENT:`, `// MASK:`,
etc.) are in context for FE-only work without loading `backend-architecture §7`.

### Canonical frontend packs (mirror of the manifest — the manifest wins)

| surface | app | Always | Keyword overlays | Never |
|---|---|---|---|---|
| `web` | customer-portal (Next.js) | `nextjs-patterns`, `react-component-patterns`, `frontend-design-system`, `accessibility-standards`, `observability-frontend` | state→`zustand-state-management` · auth→`authorization-patterns` · upload→`file-pipeline-patterns` | — |
| `admin` | tagin-console (Next.js) | `nextjs-patterns`, `nextjs-admin-patterns`, `react-component-patterns`, `frontend-design-system`, `accessibility-standards`, `observability-frontend` | same as web | — |
| `mobile` | vendor-app (RN/Expo) | `react-native-patterns`, `react-component-patterns`, `accessibility-standards` (core only), `observability-frontend` | same as web | `frontend-design-system` |

> `accessibility-standards`: web/admin load the full skill (core + web-DOM
> appendix); mobile loads the **cross-cutting core section only** — native a11y
> implementation is owned by `react-native-patterns §2.11`.
>
> `auth` overlay routes to `authorization-patterns` (the claim contract, with
> `.specify/memory/auth_contract.md`). Frontend auth *mechanics* are already in
> the surface skill (`nextjs-patterns` NextAuth v5 for web/admin;
> `react-native-patterns` expo-auth-session for mobile). There is **no**
> `auth-patterns` skill and **no** `keycloak-patterns` skill — backend AuthN
> wiring lives in `infrastructure-wiring`.

## Step 4 — Announce

List the resolved `active_surface`, code root, and the exact packs loaded before
continuing. If review/verify/test resolves a different pack set than codegen
would for the same surface, that is a bug in this preamble or the manifest —
they must match.
