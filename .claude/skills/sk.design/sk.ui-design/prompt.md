# sk.ui-design
Defines the frontend UI model for a unit.
Role: frontend | Level: unit
ONE document per unit — covers the frontend surface for all stories in the unit.

Internal sub-skill — invoked by sk.design Phase 6. Do not invoke directly.

## Boundary with sk.contracts (read first)
The architect's `sk.contracts` already declared WHICH endpoints exist and which this frontend consumes
(see `contracts/test-plan.md` → consumer section). This skill does NOT redefine endpoints, URLs, or
response field ownership. It defines HOW the frontend types, fetches, and renders those responses.
If a needed endpoint is missing from the contract, do not invent it — record it under Open Questions
and flag it for the architect (sk.design --contracts).

## Step 0: Capability Pack Selection
Load the frontend packs relevant to this unit's surface before designing. **Load ≤6 packs total.**

1. Read session.yaml → get `active_unit`, `active_intent`, and `role`.
2. Read unit-brief.md and all stories → check `tags` arrays and prose for surface + concern keywords.
3. Identify the target surface(s): customer portal (Next.js) | admin SPA (React+Vite) | mobile (React Native).
4. Read applicable packs:

- Always: `.claude/skills/frontend-design-system/SKILL.md`
- Always: `.claude/skills/react-component-patterns/SKILL.md`
- `portal`, `web`, `next`, `nextjs`, `app router`, `ssr`, `seo`, `strapi`, `cms` → `.claude/skills/nextjs-patterns/SKILL.md`
- `admin`, `spa`, `vite`, `tanstack`, `dashboard`, `back office`, `internal tool` → `.claude/skills/react-admin-patterns/SKILL.md`
- `mobile`, `native`, `react native`, `expo`, `nativewind`, `ios`, `android` → `.claude/skills/react-native-patterns/SKILL.md`
- `state`, `global`, `store`, `zustand`, `shared state`, `client cache` → `.claude/skills/zustand-state-management/SKILL.md`
- `a11y`, `accessibility`, `wcag`, `keyboard`, `screen reader`, `aria` → `.claude/skills/accessibility-standards/SKILL.md`
- `telemetry`, `analytics`, `observability`, `posthog`, `sentry`, `web vitals` → `.claude/skills/observability-frontend/SKILL.md`

List the packs loaded before continuing.

## Path Resolution (per story-lifecycle.md §3)
Resolve `UNIT_DIR` from session.yaml `unit_dir`. The UI model is written to
`UNIT_DIR/02-design/ui-model.md`. Legacy fallback (no unit_dir): the unit paths below.

## Input Artifacts
UNIT_DIR/stories/ (story.md, acceptance-criteria.md)
UNIT_DIR/02-design/architecture.md            (route/page intent, data flow, security)
UNIT_DIR/02-design/api-spec.json              (endpoints this UI consumes — if it exists)
UNIT_DIR/02-design/test-plan.md               (consumer section for this surface — if it exists)
UNIT_DIR/02-design/database-design.md         (entity shapes, optional — read only if present)
.specify/memory/domain-model.md
.specify/memory/standards/coding-standards.md
.claude/skills/design-principles/SKILL.md
(Legacy fallback inputs: specs/intents/{intent}/units/{unit}/{unit-brief,architecture,data-model}.md + stories/ + contracts/)

## Steps
1. [REFINE MODE] if ui-model.md exists, [CREATE MODE] if not.
   - REFINE: read existing fully, preserve valid sections, update only changed surfaces. Append a revision note.
2. List every story in the unit. Confirm the UI model covers each one (each story maps to at least one
   route or component path). A story with no frontend surface is recorded as "no UI — backend only".
3. **Route & Page Tree** — define the route structure for the target surface
   (App Router segments / SPA routes / mobile screens), route groups, layouts, loading and error boundaries.
4. **Component Architecture** — decompose each page into components. For every component declare:
   - render boundary: server | client (portal) — or container | presentational (SPA/mobile)
   - single responsibility (one visual concern or one interaction)
   - shared vs unit-local (shared only if reused in 3+ places — per react-component-patterns)
5. **State Architecture** — classify every piece of state into exactly one home and justify it:
   - server cache (Next.js cache / TanStack Query) — server-owned data
   - global client store (Zustand) — cross-component UI state only
   - local component state — single-component concern
   Rule: server-owned data never lives in Zustand. Global store holds UI state, not server snapshots.
6. **Data Consumption Contracts** — define the TypeScript interfaces that map the consumed API responses
   (from api-spec.json) into frontend types. Reference the contract; never restate endpoint ownership.
   Declare the fetch strategy per route (Static / ISR / Dynamic / client-fetch) with rationale.
7. **Design System Usage** — list the shadcn/ui components used, any custom components required (and why),
   and any feature-specific token decisions. Reuse existing tokens; do not introduce a new visual style.
8. **Performance Strategy** — SSR/ISR/Static per route, bundle split points (dynamic imports for heavy
   client components), image strategy, and any Core Web Vitals targets for this unit.
9. **Accessibility Requirements** — WCAG 2.2 AA targets for this unit, keyboard navigation paths,
   focus management, and ARIA decisions for any non-native interactive component.
10. **Error & Loading States** — for every async surface: loading UI, empty state, and error fallback.
11. Write the UI model document using `templates/artifacts/ui-model-template.md` as the structure.

## Frontend Engineering Review (mandatory — runs after step 11)
Validate the written UI model against:
- `.claude/skills/design-principles/SKILL.md` — access-pattern-first; UI consumes contracts, does not invent them
- `architecture.md` — every route/page the architecture implies has a home; no surface is orphaned
- `contracts/api-spec.json` / `test-plan.md` — every consumed field exists in the contract; no invented endpoints
- the loaded frontend packs — server/client split, state placement, and form patterns follow the packs

Flag findings as:
- BLOCKING: consumes an endpoint or field absent from the contract; server-owned data placed in global store;
  a story's UI surface is missing entirely; client/server boundary that breaks the framework's rules
  (e.g. `'use client'` at layout root forcing the whole subtree client-side)
  → fix the UI model before proceeding.
- MEDIUM: state placed in the wrong home without justification; missing loading/error/empty state for an
  async surface; missing accessibility target on an interactive component; heavy client component not split
  → must be resolved before proceeding; counts as a blocker in autopilot mode.
- ADVISORY: a new shared component or cross-surface pattern is introduced
  → suggest recording it in the unit knowledge base before implementation begins.

If all checks pass: report "Frontend engineering review passed — no findings."
If only ADVISORY findings: report "Frontend engineering review passed with advisories." and list them.
If any MEDIUM or BLOCKING findings exist: report "Frontend engineering review FAILED." and list all findings.

## Output Artifacts
UNIT_DIR/02-design/ui-model.md   (legacy fallback: specs/intents/{intent}/units/{unit}/ui-model.md)
UNIT_DIR/02-design/knowledge-base.md
  (frontend section updated only if a non-derivable UI decision was made — see step below)

## Steps (continued)
12. If the UI model introduced a non-derivable decision (a shared component contract other units will depend on,
    a deliberate state-architecture tradeoff, an accessibility constraint driven by an external requirement):
    update the unit knowledge-base.md with the rationale (why, not what). Otherwise log
    "KB update skipped — no non-derivable UI content."

## Quality Bar
- Every unit story is mapped to a route/component path, or explicitly marked "no UI — backend only"
- Every component declares its render boundary (server/client or container/presentational) and single responsibility
- Every piece of state has exactly one declared home with a justification
- Server-owned data is never placed in the global client store
- Every consumed field traces to an endpoint in api-spec.json — no invented endpoints or fields
- Fetch strategy (Static/ISR/Dynamic/client) declared per route with rationale
- Every async surface has loading, empty, and error states defined
- Accessibility target (WCAG 2.2 AA) declared for every interactive component
- Shared components reused in 3+ places only; feature-local otherwise
- No new visual style introduced — existing design tokens reused
- Open questions listed, not hidden; missing contract endpoints flagged to the architect
- Revision note appended if REFINE MODE
