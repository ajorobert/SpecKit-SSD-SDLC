# sk.story — Unified Story Capture Orchestrator
Runs the complete story capture and clarification pipeline.
Role: po (orchestrator) | Level: story

This skill orchestrates `sk.specify`, `sk.clarify`, and `sk.architect-probe` in sequence, running completeness checks and looping clarification as needed for both business and technical aspects.

## Mode Detection
Evaluate in this order:
**TARGETED**
- `sk.story --specify` → run Phase 1 only (standalone intent/unit/story capture)
- `sk.story --clarify` → run Phase 3 only (standalone business ambiguity resolution)
- `sk.story --probe` → run Phase 5 only (standalone technical constraints resolution)

**FULL PIPELINE**
- `sk.story` (no flag) → [FEATURE MODE]
- `sk.story --bug` → [BUG MODE]
- `sk.story --jira <KEY>` → [JIRA MODE] — read the Jira task `<KEY>` and generate **two sibling stories** (frontend + backend) from it.
  - Add `--single` to instead produce one story with Frontend/Backend sub-sections.
  - Example: `sk.story --jira AUTH-102`

## Pre-flight
1. Read `session.yaml`
2. Load `.specify/memory/system-context.md`, `.specify/memory/architecture-decisions.md`, `.specify/memory/domain-model.md`
3. Load `.specify/memory/standards/story-lifecycle.md` — the canonical path/lifecycle reference. All story paths in this skill resolve through it (§2, §3).

## Path Resolution & Story IDs (per story-lifecycle.md §2–§3)
- **Resolve the unit** — require `active_intent_id` + `active_unit_id` (→ `unit_dir`) in
  `session.yaml`. MISSING → STOP: run `sk.intent` then `sk.unit` first (they create
  `intent.md` / `unit-brief.md` and focus the session). Stories are always captured under an
  existing unit.
- `STORIES_DIR = UNIT_DIR/stories/`. Read the intent code (from `intent.md`) and unit code (from
  `unit-brief.md`) — story files are named `story-{Layer}-{INTENT}-{UNIT}-{NNN}.md`.
- **Story id per layer** — for each layer (Frontend / Backend / Mobile) being captured, glob
  `STORIES_DIR/story-{Layer}-{INTENT}-{UNIT}-*.md`, take `max NNN + 1`, zero-pad to 3.
  Set `active_story_id` to the focused story's id (`{INTENT}-{UNIT}-{NNN}`).
- **One unit == one feature == one branch.** A unit may carry several stories (one per impacted
  layer); the active unit is the working focus. Acceptance criteria live **inside** each story file.
- **Backward compatibility:** pre-existing `stories/story-{ID}.md` files are read/updated in place
  (story-lifecycle.md §6).

## Orchestration

### Phase 0 — Jira Ingest ([JIRA MODE] only)
Skip this phase entirely unless invoked with `--jira <KEY>`.
1. **Fetch the Jira task** `<KEY>`:
   - Preferred: Atlassian MCP (Rovo) — call `getJiraIssue` for `<KEY>`.
   - Fallback: if the Atlassian MCP is not connected, call the Jira REST API via curl:
     `GET {JIRA_BASE_URL}/rest/api/3/issue/<KEY>` using Basic auth from env
     (`$JIRA_EMAIL` + `$JIRA_API_TOKEN`). If neither is available, STOP and ask the
     user to reconnect the Atlassian MCP or provide REST credentials.
2. **Extract** from the issue: summary, description, acceptance criteria, components/labels, issue type.
3. **Map** Jira fields → story seeds (actor / action / value / acceptance criteria).
4. **Set the split plan**:
   - Default → emit **TWO** stories: one `frontend`, one `backend`.
   - `--single` → emit ONE story with `## Frontend` and `## Backend` sub-sections.
5. Carry these onto every generated story's frontmatter:
   ```yaml
   jira_id: <KEY>
   source: jira
   layer: frontend        # or backend (per pass)
   sibling_story: <other story id>   # cross-link (two-story mode only)
   ```

### Phase 1 — Story Capture
Invoke sub-skill: `sk.story/sk.specify` (or `--bug` if in bug mode).
- **[JIRA MODE, default]**: run sk.specify **once per layer** (frontend, then backend),
  seeding each pass with the Jira-derived seeds plus a layer lens:
  - Frontend pass → actor = end user; acceptance criteria about UI/UX; `role: frontend`;
    tags lean to `state` / `bff`.
  - Backend pass → actor = system/service; acceptance criteria about API contracts, data,
    persistence; `role: backend`; tags lean to `db` / `auth` / `messaging`.
  - **Filename**: write each split story as `story-{Layer}-{ID}.md` where `{Layer}` is the
    capitalized layer (`Frontend` / `Backend`) — e.g. `story-Frontend-AUTH-LOGIN-001.md`,
    `story-Backend-AUTH-LOGIN-002.md`. The `id` frontmatter stays `{INTENT-CODE}-{UNIT-CODE}-{NNN}`
    (the layer prefix is filename-only).
  After both are written, set each story's `sibling_story` to the other's ID.
- **[JIRA MODE, --single]**: run sk.specify once; write Frontend and Backend sub-sections.
- Wait for specify phase to complete and write `story-{ID}.md`.
- Read back `active_story_id` from `session.yaml` (the last story written; track all generated IDs).

> **[JIRA MODE, two-story]**: Phases 2–6 below run **once per generated story** (frontend
> and backend). Assess, clarify, and validate each story independently; a gap in one does not
> block the other. The Completion Report then summarizes both.

### Phase 2 — Business Completeness Assessment
Run a structural coverage check on the generated `story-{ID}.md`.
Score each item below as ✅ Clear, ⚠️ Partial, or ❌ Missing.

**Business Checklist:**
- Story Structure
  - [ ] User story follows "As a / I want / So that" format
  - [ ] Actor is a specific role, not generic ("user")
  - [ ] Action is a concrete verb, not abstract ("manage")
  - [ ] Value connects to a business outcome
- Acceptance Criteria
  - [ ] Minimum 3 criteria present
  - [ ] At least 1 negative/error scenario covered
  - [ ] All criteria are testable (GWT or condition-based)
  - [ ] No vague qualifiers without metrics
- Scope
  - [ ] Out-of-scope section is populated (not empty)
  - [ ] No implicit scope assumptions

Gather all items marked ⚠️ Partial or ❌ Missing as seeds for Phase 3.
If all items are ✅ Clear, skip Phase 3 and go to Phase 4.

### Phase 3 — Iterative Business Clarification
Loop `sk.story/sk.clarify` up to 3 times to resolve the gaps identified in Phase 2.

**Round 1:**
- Present the ⚠️/❌ items to the clarify sub-skill.
- Clarify phase asks up to 5 questions.
- Integrate user answers into `story-{ID}.md`.
- Re-run Phase 2 Assessment. If all ✅, exit loop.
- **Round 2 & 3:** Repeat, adjusting questions to remaining gaps. Exit loop after Round 3 regardless.

### Phase 4 — Technical Completeness Assessment
Run an engineering readiness check on `story-{ID}.md`.
Score each item below as ✅ Clear, ⚠️ Partial, or ❌ Missing.

**Technical Checklist:**
- Integration & Data
  - [ ] Entities involved are identified and data inputs/outputs are concrete.
  - [ ] External dependencies and downstream failure modes addressed.
- NFRs & Scale
  - [ ] Performance targets, request volume, or scale expectations defined.
- Security boundaries
  - [ ] Tenant isolation or explicitly restricted actors defined.
- Observability
  - [ ] Business value telemetry/tracking metrics defined.
- UX & Design Constraints
  - [ ] Design references (Figma/assets) documented if frontend.

Gather all items marked ⚠️ Partial or ❌ Missing as seeds for Phase 5.
If all items are ✅ Clear, skip Phase 5 and go to Phase 6.

### Phase 5 — Iterative Technical Clarification
Loop `sk.story/sk.architect-probe` up to 2 times to resolve gaps from Phase 4.

**Round 1:**
- Present the ⚠️/❌ items to the architect-probe sub-skill.
- Probe phase asks up to 3 questions translating technical needs to business context.
- Integrate user answers into `story-{ID}.md`.
- Re-run Phase 4 Assessment. If all ✅, exit loop.
- **Round 2:** Repeat if needed. Exit loop after Round 2 regardless.

### Phase 6 — Final Validation Gate
Before marking the story as ready:
1. Show a combined summary of the final Business & Technical Assessments.
2. If all items are ✅ across both:
   - Auto-set `status: ready` in the story frontmatter.
   - Display success summary.
3. If any ❌ remain:
   - Display the missing items.
   - Ask PO: "Type 'proceed' to accept and proceed (items will be flagged as risk), or 'clarify' to do one more manual round."
   - If 'proceed': set `status: ready`.

### Phase 7 — Materialize `stories/` Artifacts
Once the story content is captured and validated (Phases 1–6), write one **story file per layer**
into `UNIT_DIR/stories/`. This is the authoritative output of sk.story. Each story file is
self-contained (user story + requirements + acceptance criteria + frontmatter). Create the folder
if absent; update files in place if present, preserving user-authored sections (§7).

**`stories/story-{Layer}-{INTENT}-{UNIT}-{NNN}.md`** — one per impacted layer
(`Layer ∈ Frontend | Backend | Mobile`, e.g. `story-Frontend-AUTH-LOGIN-001.md`):
```
---
id: {INTENT}-{UNIT}-{NNN}
layer: {frontend | backend | mobile}
status: ready
tags: []
checkpoint_mode: {autopilot | confirm | validate}
sibling_story: {other layer's id, if split}    # JIRA / multi-layer mode
jira_id: {KEY}                                  # if linked
---

# {id} — {Title}

## User Story
As a {actor}, I want {goal}, so that {benefit}.

## Acceptance Criteria
### AC-1: {short title}
- **Given** {precondition}
- **When** {action}
- **Then** {expected result}
### AC-2: ...
(minimum 3 criteria; at least one negative/error scenario)

## Requirements
- **Functional:** {numbered, testable}
- **Non-Functional:** {performance, scale, security, observability targets}
- **Constraints:** {technical mandates, dependencies, downstream failure modes}

## Out of Scope
{explicit exclusions}
```
Use `templates/artifacts/story-template.md` for the canonical frontmatter/section shape.
Determine which layers to write from the unit's `impacted_projects` (unit-brief.md): one story per
impacted layer (frontend/backend/mobile). Acceptance criteria live **inside** each story file —
there is no separate acceptance-criteria.md.

**`stories/jira.md`** — write only when Jira data is present (JIRA MODE or a linked ticket);
otherwise a stub noting "No Jira ticket linked.":
```
# {INTENT}-{UNIT} — Jira

Issue: {KEY}    Type: {issue type}
Summary: {summary}
Labels/Components: {…}

## Imported Description
{verbatim description}

## Imported Acceptance Criteria
{verbatim AC from Jira, if any}
```

> **[JIRA MODE / multi-layer]** — emit one story file per layer (frontend / backend / mobile)
> under the **same unit's** `stories/`; cross-link them via `sibling_story` frontmatter and the
> shared `stories/jira.md`. Add all generated story ids to `session.yaml` `stories_touched`; set
> `active_story_id` to the layer the user focuses next (default: frontend). Design → security run
> once **per unit** (shared), not per story.

## Completion Report
```
sk.story complete.
Story: {story-id} — {story title}
Status: ready

Checklist Summary:
- Business Passed: {X}/{Total}
- Technical Passed: {Y}/{Total}
- Missing: {Z} (listed if any)

Next step: /sk.design (or /sk.ff if continuing the pipeline)
```

**[JIRA MODE, two-story]** — report both stories and their link:
```
sk.story complete (from Jira {KEY}).
Frontend story: {fe-id} — {title}   Status: ready
Backend  story: {be-id} — {title}   Status: ready
Linked via jira_id: {KEY} (sibling_story cross-references set).

Checklist Summary (per story):
- {fe-id}: Business {X}/{Total}, Technical {Y}/{Total}
- {be-id}: Business {X}/{Total}, Technical {Y}/{Total}

Next step: /sk.design for each story (or /sk.ff to continue the pipeline)
```
