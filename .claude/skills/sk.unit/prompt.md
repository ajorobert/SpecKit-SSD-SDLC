# sk.unit — Capture a Feature (Unit)
Role: po | lead | Level: unit

A **unit** is one feature within an intent (e.g. *login* under *Authentication*). It is the
**lifecycle container**: `stories/` plus the numbered phase folders (`02-design` … `07`) all live
under `specs/intents/{intent}/units/{unit}/`. Paths resolve per
`.specify/memory/standards/story-lifecycle.md` (§2–§3).

## Invocation
- `sk.unit` — interview, then create the unit under the active intent
- `sk.unit "<feature name>"` — seed the unit name

## Pre-flight
1. Read `session.yaml` → require `active_intent_id` (and `intent_dir`).
   MISSING → STOP: run `sk.intent` first (or `sk.session focus --intent {id}`).
2. Read the intent: `specs/intents/{active_intent_id}/intent.md` (for the intent code + boundaries).
3. Read `.specify/memory/projects/index.md` — the project router (to record impacted projects).

## Steps

### Step 1 — Resolve Unit
- Build `{unit}` kebab name from the feature title (e.g. `login`).
- Ask for / derive a short **unit code** (uppercase, e.g. `LOGIN`).
- `UNIT_DIR = specs/intents/{active_intent_id}/units/{unit}/`.

### Step 2 — Interview (feature boundary level)
- **Feature:** what does this feature do, in one sentence?
- **User flows:** the main flow(s) end-to-end (happy path + key alternates).
- **Impacted projects:** which projects from `projects/index.md` does this feature touch?
  (backend / frontend / mobile / library) — this drives per-project design/plan/impl/test.
- **Boundaries:** what is explicitly out of scope for this unit?
- **Story split:** which layers need a story? (frontend / backend / mobile)

### Step 3 — Write `unit-brief.md`
Create `UNIT_DIR/unit-brief.md`:
```
---
id: {INTENT-CODE}-{UNIT-CODE}
intent: {active_intent_id}
unit: {unit}
impacted_projects: [{ProjectName}, ...]
---

# {INTENT-CODE}-{UNIT-CODE} — {Feature Name}

## Feature Boundary
{what this feature includes and excludes}

## User Flows
{the main end-to-end flow(s)}

## Impacted Projects
| Project | Type | Why it's impacted |
|---|---|---|
| {ProjectName} | {type} | {one line} |

## Planned Stories
- story-Frontend-{INTENT}-{UNIT}-NNN — {title}   (if frontend impacted)
- story-Backend-{INTENT}-{UNIT}-NNN — {title}    (if backend impacted)
- story-Mobile-{INTENT}-{UNIT}-NNN — {title}     (if mobile impacted)
```
Apply story-lifecycle.md §7 idempotency (update in place if the unit already exists).
Create the empty `UNIT_DIR/stories/` folder.

### Step 4 — Focus the session
Write `active_unit_id = {unit}` and `unit_dir = UNIT_DIR` to `session.yaml` (keep `active_intent_id`).

## Completion Report
```
sk.unit complete.
Unit: {INTENT-CODE}-{UNIT-CODE} — {Feature Name}
Impacted projects: {list}
Written: {UNIT_DIR}/unit-brief.md

Next step: /sk.story  (capture the per-layer stories under this unit)
```

## Quality Bar
- unit-brief.md has feature boundary, user flows, and an impacted-projects table
- impacted_projects all exist in projects/index.md
- session.yaml `active_unit_id` + `unit_dir` set
- stories/ folder created
