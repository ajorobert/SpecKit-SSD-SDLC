# sk.intent — Capture a Business Capability (Intent)
Role: po | Level: intent

Top of the spec hierarchy. An **intent** is one coherent business capability (e.g.
*Authentication*, *Checkout*, *Notifications*). Units (features) and stories live beneath it.
Paths resolve per `.specify/memory/standards/story-lifecycle.md` (§2–§3).

## Invocation
- `sk.intent` — interview, then create the intent
- `sk.intent "<capability name>"` — seed the name, then confirm details

## Pre-flight
1. Read `session.yaml`.
2. Load `.specify/memory/system-context.md`, `.specify/memory/architecture-decisions.md`,
   `.specify/memory/domain-model.md` (to detect duplicate/overlapping capabilities).

## Steps

### Step 1 — Resolve Intent ID
- Glob `specs/intents/*/`, take `max NNN + 1`, zero-pad to 3 → `{NNN}` (start at `001`).
- Build `{kebab-name}` from the capability title (lowercase, spaces → hyphens, strip punctuation).
- `intent-id = {NNN}-{kebab-name}` (e.g. `001-authentication`).
- Ask for / derive a short **intent code** (uppercase, e.g. `AUTH`) — used in story ids.

### Step 2 — Interview (keep it short — capability level, not feature level)
- **Capability:** what business capability does this represent, in one sentence?
- **Primary actors:** who uses it?
- **Business outcome:** what value does the system deliver through it?
- **Boundaries:** what is explicitly NOT part of this capability?
- **Known units:** what features (units) do you already expect under it? (optional seed list)

### Step 3 — Duplicate / Conflict Check
- Compare against existing `specs/intents/*/intent.md` and ADRs. If this duplicates or conflicts
  with an existing capability, surface it and ask whether to extend the existing intent instead.

### Step 4 — Write `intent.md`
Create `specs/intents/{intent-id}/intent.md`:
```
---
id: {intent-id}
code: {INTENT-CODE}
status: active
---

# {INTENT-CODE} — {Capability Name}

## Capability
{one-paragraph description of the business capability}

## Primary Actors
{roles}

## Business Outcome
{the value delivered}

## Boundaries (out of scope)
{what this capability does not cover}

## Units (features)
{seed list, if any — each becomes a units/{unit}/ via sk.unit}
```
Apply story-lifecycle.md §7 idempotency (update in place if the intent already exists).

### Step 5 — Focus the session
Write `active_intent_id = {intent-id}` (and `intent_dir`) to `session.yaml`. Leave
`active_unit_id` / `unit_dir` null until `sk.unit` runs.

## Completion Report
```
sk.intent complete.
Intent: {intent-id} ({INTENT-CODE}) — {Capability Name}
Written: specs/intents/{intent-id}/intent.md

Next step: /sk.unit  (define the first feature/unit under this intent)
```

## Quality Bar
- intent-id is `{NNN}-{kebab-name}`; intent code is uppercase and recorded
- Capability, actors, outcome, and boundaries all populated (no placeholders)
- Duplicate/conflict check performed against existing intents + ADRs
- session.yaml `active_intent_id` set
