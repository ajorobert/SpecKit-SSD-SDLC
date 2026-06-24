# Unit Lifecycle & Path Resolution (Canonical)

> **Single source of truth** for the enterprise lifecycle directory layout, path resolution,
> branch convention, and backward-compatibility rules.
> Every lifecycle skill (`sk.intent`, `sk.unit`, `sk.story`, `sk.design`, `sk.plan`,
> `sk.implement`, `sk.test`, `sk.uat`, `sk.security-audit`, `sk.session`, `sk.init`) loads this
> file and MUST resolve all artifact paths through it. Do not hardcode lifecycle paths.
>
> **Anchor:** the **unit** (`specs/intents/{intent}/units/{unit}/`) is the lifecycle container —
> the numbered phase folders (`02-design` … `07-security-audit`) and `stories/` live under it.
> A unit is one feature boundary that may span multiple projects and carry multiple stories
> (one per layer: frontend / backend / mobile).

---

## 1. `.specify/memory` Project Layer (created by `sk.init`)

```
.specify/memory/
  projects/
    index.md                          # ROUTER (always loaded): project | type | code-root
    {ProjectName}/
      project.md
      tech-stack.md
      coding-standards.md
  standards/
    api-standards.md                  # shared, cross-project
    data-standards.md                 # shared, cross-project
    observability-standards.md        # shared, cross-project
    story-lifecycle.md                # this file
```

`projects/index.md` rows — `type ∈ backend | frontend | mobile | library`:
```
project | type | code-root

Backend.API | backend | src/backend
Customer.Web | frontend | src/web
Mobile.App | mobile | src/mobile
```

---

## 2. Spec Layer — Intent → Unit → Lifecycle

```
specs/
  intents/
    {intent-id}/                      # sk.intent   e.g. 001-authentication
      intent.md                       #   business capability (code, e.g. AUTH)
      units/
        {unit}/                       # sk.unit     e.g. login
          unit-brief.md               #   feature boundary, user flows, impacted projects (AUTH-LOGIN)
          stories/                    # sk.story
            story-{Layer}-{INTENT}-{UNIT}-{NNN}.md   # story-Frontend-AUTH-LOGIN-001.md
            jira.md                   #   optional imported Jira source
          02-design/                  # sk.design
            architecture.md  impact-analysis.md  api-contract.md  api-spec.json  database-design.md
            projects/{ProjectName}.md
          03-plan/{ProjectName}/      # sk.plan
            plan.md  tasks.md  checklist.md  jira-subtask.md  estimation.md
          04-implementation/{ProjectName}/   # sk.implement
            implementation.md  progress.md  validation.md
          05-test/{ProjectName}/      # sk.test
            (backend/library) unit-test.md  integration-test.md  contract-test.md
            (frontend/mobile) component-test.md  contract-test.md
          06-uat/                     # sk.uat
            acceptance-result.md  user-flow-test.md  signoff.md
          07-security-audit/          # sk.security-audit
            owasp-report.md  stride-review.md  dependency-scan.md  security-signoff.md
```

The pipeline flows in order; each phase reads the prior phase's outputs:
```
stories → 02-design → 03-plan → 04-implementation → 05-test → 06-uat → 07-security-audit
(Story  → Design    → Plan    → Implementation    → Test    → UAT    → Security Audit → release)
```

### Naming
- **intent-id** = `{NNN}-{kebab-name}`, globally incrementing (`001-authentication`). The short
  **intent code** (e.g. `AUTH`) is recorded inside `intent.md`.
- **unit** = `{kebab-name}` (`login`). The **unit code** (e.g. `LOGIN`) is recorded in `unit-brief.md`.
- **story file** = `story-{Layer}-{INTENT}-{UNIT}-{NNN}.md`, `Layer ∈ Frontend | Backend | Mobile`
  (e.g. `story-Frontend-AUTH-LOGIN-001.md`). Acceptance criteria live **inside** the story file.

`{ProjectName}` always matches a `project` name in `memory/projects/index.md`.

---

## 3. Path Resolution (use this everywhere)

```
INTENT_DIR = specs/intents/{intent-id}/
UNIT_DIR   = INTENT_DIR/units/{unit}/                 # the lifecycle anchor
PHASE_DIR  = UNIT_DIR/{NN-phase}/                      # e.g. UNIT_DIR/02-design/
PROJECT_PHASE_DIR = UNIT_DIR/{NN-phase}/{ProjectName}/ # for 03/04/05
```

Resolve the active unit in this order:
1. `session.yaml` → `unit_dir` (root-relative path written by `sk.unit` / `sk.session`). Use verbatim.
2. Else `session.yaml` → `active_intent_id` + `active_unit_id`: build
   `specs/intents/{active_intent_id}/units/{active_unit_id}/`.
3. Else STOP and instruct: run `sk.intent` / `sk.unit` / `sk.session focus` first.

`active_story_id` selects the **focused story file** within `UNIT_DIR/stories/` (used by
story-level skills that operate on one layer). The unit, not the story, owns design→security.

When a skill creates or first resolves the unit, it MUST write `active_intent_id`,
`active_unit_id`, and `unit_dir` back to `session.yaml`.

**Next ids:** intent — glob `specs/intents/*/`, take `max NNN + 1`, zero-pad 3. story — glob the
unit's `stories/story-{Layer}-*-{NNN}.md`, take `max NNN + 1` per unit.

---

## 4. Project scoping (03 / 04 / 05)

Planning, implementation, and testing are **project-scoped**: one subfolder per participating
project under the unit, named by its `memory/projects/index.md` entry. Determine participating
projects from:
- explicit `--project {ProjectName}` flag, else
- the per-project design files under `02-design/projects/`, else
- `memory/projects/index.md` filtered by `--role` (`backend` → `backend`/`library`;
  `frontend` → `frontend`/`mobile`).

A project's `type` selects which files a phase emits (see 05-test in §2).

---

## 5. Branch & Session Convention

- **Default base branch:** `dev` (override to current branch or a custom name).
- **Branch name:** `feature/{intent-id}/{unit}-{YYYYMMDD}`
  - Example: `feature/001-authentication/login-20260624`
  - Keep `{intent-id}` and `{unit}` verbatim; append today's date.
- **One feature branch == one unit** (the feature boundary). A unit spans multiple projects and
  may carry frontend/backend/mobile stories; a session may carry multiple roles. The active unit
  is the session's working focus.

---

## 6. Backward Compatibility

- The intent→unit hierarchy is the established layout; pre-existing
  `specs/intents/{intent}/units/{unit}/` content (loose `architecture.md`, `data-model.md`,
  `contracts/`, `stories/story-*.md`) is read in place. When a skill writes a phase artifact, it
  creates the matching numbered phase folder and writes there; it never deletes prior content.
- An earlier iteration used flat `specs/STORY-{ID}-{slug}/` folders. If any exist, read them in
  place; new work uses the unit-anchored layout. Never `rm` — use `.claude/hooks/archive-file.sh`.

---

## 7. Idempotency rules (all skills, all phases)

- Create folders/files if absent; **update in place** if present — never wipe a folder.
- Preserve user-authored sections and notes not derived from the current run.
- Never delete a phase, unit, intent, or project folder. Stale items are noted, not removed.
- Merge registry rows (`projects/index.md`) by `project` name — no duplicates.
