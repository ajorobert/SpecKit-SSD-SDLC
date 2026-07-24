# sk.specify
Captures intent, decomposes to units and stories.
Role: po | Level: intent → unit → story

## Mode Detection
- `sk.specify --bug` → [BUG MODE] bug report interview framing
- `sk.specify` (no flag) → [FEATURE MODE] user story interview framing
Declare mode at start of execution.

**Jira-seeded capture:** When the orchestrator passes Jira seed data (from `sk.story --jira {Jira_Id}`), use it to PRE-FILL the interview matrix (Actor, Action, Value, Trigger, Input, Output, Happy Path, Error Cases) and the acceptance criteria. Only ask the PO about dimensions Jira left genuinely empty or ambiguous — do not re-ask what the Jira task already answers. Set `jira_id: {Jira_Id}` in story frontmatter. The orchestrator also passes `detected_projects` (Jira Components already resolved to project names via `.specify/memory/jira-component-map.md`) — write these into the `## Project` section of `story.md` (see Step 5).

## Input Artifacts
.specify/memory/system-context.md
.specify/memory/projects/index.md (project router)
session.yaml (active_intent_id, active_unit_id)

## Steps

### Step 1 — Resolve Intent
Read active_intent_id from session.yaml.
NULL → ask user for intent title and code (e.g. CHK)
Create specs/intents/{NNN}-{name}/intent.md if new.

### Step 2 — Resolve Unit
Read active_unit_id from session.yaml.
NULL → ask user for unit title and code (e.g. PAY)
Create specs/intents/{intent}/units/{unit}/unit-brief.md if new.

### Step 3 — [FEATURE MODE only] Pre-validation (optional)
If creating a new intent (active_intent_id was NULL before step 1):
  Ask: "Would you like to validate this idea against existing intents and constraints first? (y/n)"
  If yes:
    - Load .specify/memory/system-context.md and list existing intents from specs/intents/
    - Load .specify/memory/architecture-decisions.md and .specify/memory/domain-model.md
    - Evaluate: does this idea duplicate an existing intent? does it conflict with any ADR?
    - Report findings. If major concerns: suggest resolving before proceeding.
    - If no concerns: confirm "No conflicts found. Proceeding to story capture."

### Step 3b — Context-Aware Probing (optional)
Before asking questions, load:
- Existing story folders in the same unit (`specs/intents/{intent}/units/{unit}/{NN}-story/`) to avoid duplication.
- `.specify/memory/domain-model.md` to probe for entity relationships.
- `.specify/memory/system-context.md` to check if the story touches integration points.
Use this to generate 1-2 proactive questions (e.g. "This story involves the Order entity. Does it need to handle state transitions?").

### Step 3c — Load Project Router
Before capturing the story, load `.specify/memory/projects/index.md` as the project router.
Use it to ground the requirement in the actual workspace:
- **Available projects:** enumerate the projects and their types (Backend / Frontend / Mobile) so story capture is aware of which surfaces exist.
- **Existing features:** scan the listed project folders for overlapping capabilities to avoid duplicating an existing feature.
- **Domain context:** cross-reference `.specify/memory/domain-model.md` for the entities the story touches.
- **Business rules:** carry any project-level constraints into the interview.
The story is NOT split per project. Project impact is resolved later in `sk.architect-probe`, which records the **impacted projects** into `unit-brief.md`. This step only ensures the captured requirement is project-router-aware.

### Step 4 — Capture Story

#### [FEATURE MODE]
Use the following structured interview matrix. Ask questions progressively, using follow-ups when triggered:

| Dimension | Required Question | Follow-up Trigger |
|-----------|-------------------|-------------------|
| **Actor** | Who is the primary user? What role/persona? | If "admin" or "system" → ask: is this user-facing or internal? |
| **Action** | What specific action do they perform? | If vague verb ("manage", "handle") → ask for concrete sub-actions |
| **Value** | What business outcome does this enable? | If only technical reason → push for user-facing benefit |
| **Trigger** | What initiates this action? (user click, schedule, event) | If event-driven → ask: what produces the event? |
| **Input** | What data does the user provide or the system receive? | If "form data" → ask for specific fields |
| **Output** | What is the observable result? | If no UI change → ask: how does the user know it worked? |
| **Happy Path**| Walk through the ideal scenario step by step | If > 5 steps → suggest splitting into multiple stories |
| **Error Cases**| What can go wrong? How should errors surface? | If "show error message" → ask for specific error states |

**Acceptance Criteria Quality Gate (Inline Check)**
After the PO provides acceptance criteria, verify:
- [ ] Each criterion is **testable** (has a Given/When/Then or clear condition)
- [ ] Each criterion is **independent** (doesn't duplicate another)
- [ ] No **vague adjectives** ("fast", "intuitive", "robust") without quantification
- [ ] At least one **negative/error scenario** is covered
- [ ] At least one criterion addresses **the core value proposition**
If any check fails → ask a targeted follow-up before writing the story.

Ask explicitly: what is explicitly out of scope.

#### [BUG MODE]
- Ask: what is the expected behavior? (reference the relevant spec, story ID, or acceptance criterion if known)
- Ask: what is the actual/broken behavior? (be specific — what happens instead)
- Ask: steps to reproduce (numbered list)
- Ask: affected unit and story ID if known (set as `related_story` in frontmatter)
- Ask: acceptance criteria for the fix — when is this considered resolved? (minimum 2)
- Note: out of scope defaults to "no new features introduced by this fix"

### Step 5 — Write Story
Create a single numbered story folder (the story is NOT split per project):
  specs/intents/{intent}/units/{unit}/{NN}-story/
where `{NN}` is the next zero-padded sequence within the unit (`01-story`, `02-story`, …).
Story ID format stays `{INTENT}-{UNIT}-{NNN}` and is recorded in `story.md` frontmatter.

Write these files into that folder:
  - `story.md` — frontmatter (`id`, `intent`, `unit`, `status`, `story_type`, `tags`, `checkpoint_mode`; plus `jira_id` when Jira-seeded) + the As-a/I-want/So-that user story + in/out-of-scope.
  - `requirement.md` — the functional + non-functional business requirements derived from the interview.
  - `acceptance-criteria.md` — the testable acceptance criteria (GWT or condition-based).

**`## Project` section in `story.md` (project-scope signal for sk.design):**
Write this section ONLY when the orchestrator passed a non-empty `detected_projects` list
(Jira mode with mapped Components). Place it after the in/out-of-scope body. Format — one
mapped project name per bullet, exactly as it appears in the mapping / project router:
```
## Project
- Backend.API
- Admin.Panel
```
- Single detected project → one bullet. Multiple → one bullet each, de-duplicated.
- If `detected_projects` is empty or absent (manual mode, or no/unmapped Components):
  do NOT write a `## Project` section at all — never write an empty one. Its absence tells
  `sk.design` to fall back to full impact analysis.
- Do not invent or alter project names here; use exactly what the mapping produced.

In [BUG MODE]: set `story_type: bug` in `story.md` frontmatter and populate (in `story.md`):
  - `expected_behavior`
  - `actual_behavior`
  - `reproduction_steps`
  - `related_story` (if provided)

When Jira-seeded: also write `jira.md` in the folder recording the source `{Jira_Id}`, issue summary, and a link back. In manual mode `jira.md` is not created.

### Step 5b — Tag Story with Domain Keywords
After writing the story, scan the story title and acceptance criteria for tech domain signals.
Set the `tags` array in `story.md` frontmatter using keywords from this list:

| Keyword to add | When present in story |
|---|---|
| `auth` | login, logout, session, token, keycloak, firebase, permission, role, authorization |
| `messaging` | event, queue, rabbitmq, masstransit, mediatr, publish, subscribe, hangfire, background job |
| `workflow` | elsa, workflow, sla, timer, breach, escalation, state machine |
| `db` | schema, migration, entity, table, postgres, postgis, seed |
| `cache` | redis, cache, ttl, rate-limit, distributed lock, session store |
| `search` | elasticsearch, search, geo, location, index, facet |
| `file` | upload, download, image, virus, scan, storage, r2, cdn |
| `bff` | api gateway, bff, backend-for-frontend, aggregation, forwarding |
| `state` | zustand, global state, shared state, store |

Add matched tags to `story.md` frontmatter as: `tags: [tag1, tag2]`
Empty array if none match: `tags: []`

### Step 6 — Classify Checkpoint
Read governance skill → set checkpoint_mode in `story.md` frontmatter.
Bug stories default to checkpoint_mode: standard unless the fix touches
a service boundary or data model (→ confirm).

## Output Artifacts
specs/intents/{intent}/intent.md (if new)
specs/intents/{intent}/units/{unit}/unit-brief.md (if new)
specs/intents/{intent}/units/{unit}/{NN}-story/story.md
specs/intents/{intent}/units/{unit}/{NN}-story/requirement.md
specs/intents/{intent}/units/{unit}/{NN}-story/acceptance-criteria.md
specs/intents/{intent}/units/{unit}/{NN}-story/jira.md (only when Jira-seeded)

## Quality Bar

### Feature mode
- Story has clear user story format
- Minimum 3 acceptance criteria
- checkpoint_mode set in `story.md` frontmatter
- Out of scope items listed
- `## Project` section written in `story.md` iff `detected_projects` is non-empty (Jira mode);
  never written empty; project names verbatim from the mapping

### Bug mode
- Expected vs actual behavior clearly distinguished
- Reproduction steps are numbered and specific
- Minimum 2 acceptance criteria (definition of fixed)
- story_type: bug in frontmatter
- checkpoint_mode set (default: standard)
