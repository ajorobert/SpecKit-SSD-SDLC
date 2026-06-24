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

## Path Resolution & Story ID (per story-lifecycle.md §3)
- **Continue existing story** — if `session.yaml` already has an `active_story_id` / `story_dir`
  for the work in progress, reuse that exact STORY id and folder. Do NOT mint a new id.
- **New story** — compute the next sequence number: glob `specs/STORY-*/` (and legacy
  `specs/intents/**/story-*.md`), take `max numeric + 1`, zero-pad to 3 → `{ID}` (e.g. `001`).
  Set `active_story_id = "STORY-" + {ID}` (e.g. `STORY-001`).
  Build the `{feature-name}` slug from the story title (lowercase, spaces → hyphens, strip punctuation).
- `STORY_DIR = specs/{active_story_id}-{feature-name}/` (e.g. `specs/STORY-001-customer-login/`).
  `active_story_id` already includes `STORY-` — do NOT prepend another. Phase-1 outputs live in
  `STORY_DIR/01-story/`.
- After resolving/creating the folder, write `active_story_id` and `story_dir` back to `session.yaml`.
- **One story == one independent feature.** The current story is always the working focus.
- **Backward compatibility:** if the target story exists only under the legacy
  `specs/intents/**` layout, read it in place and offer migration per story-lifecycle.md §6
  (copy, never move/delete).

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

### Phase 7 — Materialize `01-story/` Artifacts
Once the story content is captured and validated (Phases 1–6), write it into the canonical
phase-1 folder `STORY_DIR/01-story/`. This is the authoritative output of sk.story. Split the
captured content across four files (create folder if absent; update in place if present —
preserve any user-authored sections per story-lifecycle.md §7):

**`01-story/story.md`** — the narrative:
```
# {STORY-ID} — {Title}

## User Story
As a {actor}, I want {goal}, so that {benefit}.

## Actor
{the specific role — not generic "user"}

## Goal
{the concrete action/outcome}

## Benefit
{the business value}

## Out of Scope
{explicit exclusions}
```

**`01-story/requirement.md`** — requirements & constraints:
```
# {STORY-ID} — Requirements

## Functional Requirements
{numbered, testable}

## Non-Functional Requirements
{performance, scale, security, observability targets}

## Constraints
{technical mandates, dependencies, downstream failure modes}
```

**`01-story/acceptance-criteria.md`** — testable scenarios (this file is the contract `sk.uat`
validates against, per story-lifecycle.md):
```
# {STORY-ID} — Acceptance Criteria

## AC-1: {short title}
- **Given** {precondition}
- **When** {action}
- **Then** {expected result}

## AC-2: ...
(minimum 3 criteria; at least one negative/error scenario)
```

**`01-story/jira.md`** — optional; write only when Jira data is present (JIRA MODE or a linked
ticket). Otherwise create a stub noting "No Jira ticket linked.":
```
# {STORY-ID} — Jira

Issue: {KEY}
Type: {issue type}
Summary: {summary}
Labels/Components: {…}

## Imported Description
{verbatim description}

## Imported Acceptance Criteria
{verbatim AC from Jira, if any}
```

> **[JIRA MODE, two-story]** — mint **two** STORY ids (consecutive, e.g. `STORY-001` frontend +
> `STORY-002` backend), each with its own `specs/{active_story_id}-{slug}/01-story/` folder.
> Cross-link them via `jira.md` and the `sibling_story` frontmatter on each `story.md`. Add **both**
> ids to `session.yaml` `stories_touched`; set `active_story_id`/`story_dir` to whichever the user
> focuses next (default: the first/frontend story). Downstream phases run per focused story.
>
> **Backward compatibility:** the legacy single `story-{ID}.md` may still be written for tools
> that read it, but `01-story/` is the canonical source going forward.

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
