# Story Lifecycle & Path Resolution (Canonical)

> **Single source of truth** for the enterprise story-lifecycle directory layout, path
> resolution, branch convention, and backward-compatibility/migration rules.
> Every lifecycle skill (`sk.story`, `sk.design`, `sk.plan`, `sk.implement`, `sk.test`,
> `sk.uat`, `sk.security-audit`, `sk.session`, `sk.init`) loads this file and MUST resolve
> all artifact paths through it. Do not hardcode lifecycle paths inside individual skills.

---

## 1. `.specify` Directory Structure

```
.specify/
  memory/
    projects/
      index.md                      # lightweight router: project | type | code-root
      {ProjectName}/
        project.md
        tech-stack.md
        coding-standards.md
    standards/
      api-standards.md              # shared, cross-project
      data-standards.md             # shared, cross-project
      observability-standards.md    # shared, cross-project
```

`memory/projects/index.md` is the **router**. Every lifecycle skill that needs to know which
projects exist (and where their code lives) reads this file first. Format — one row per
project, pipe-delimited:

```
project | type | code-root

Backend.API | backend | src/backend
Customer.Web | frontend | src/web
Admin.Panel | frontend | src/web/admin
Mobile.App | mobile | src/mobile
Shared.Kernel | library | src/shared
```

`type` ∈ `backend | frontend | mobile | library`.

---

## 2. Story Folder Layout (the 7-phase lifecycle)

Each story owns one folder under `specs/`, named `STORY-{ID}-{feature-name}`:

```
specs/
  STORY-{ID}-{feature-name}/
    01-story/                       # sk.story
    02-design/                      # sk.design
    03-plan/                        # sk.plan        (project-scoped subfolders)
    04-implementation/              # sk.implement   (project-scoped subfolders)
    05-test/                        # sk.test        (project-scoped subfolders)
    06-uat/                         # sk.uat
    07-security-audit/              # sk.security-audit
```

- `{ID}` — zero-padded sequence, e.g. `001`. IDs are global and monotonically increasing
  across the whole `specs/` tree.
- `{feature-name}` — branch-friendly kebab slug of the story title
  (lowercase, spaces → hyphens, strip punctuation). Example: `STORY-001-customer-login`.

The pipeline flows strictly in this order; each phase reads the prior phase's outputs:

```
01-story → 02-design → 03-plan → 04-implementation → 05-test → 06-uat → 07-security-audit
(Story  →  Design   →  Plan    →  Implementation    →  Test   →  UAT   →  Security Audit  →  Release readiness)
```

### Phase → file map

| Phase folder | Skill | Files |
|---|---|---|
| `01-story/` | sk.story | `story.md`, `requirement.md`, `acceptance-criteria.md`, `jira.md` (optional) |
| `02-design/` | sk.design | `architecture.md`, `impact-analysis.md`, `api-contract.md`, `database-design.md`, `projects/{ProjectName}.md` |
| `03-plan/{ProjectName}/` | sk.plan | `plan.md`, `tasks.md`, `checklist.md`, `jira-subtask.md`, `estimation.md` |
| `04-implementation/{ProjectName}/` | sk.implement | `implementation.md`, `progress.md`, `validation.md` |
| `05-test/{ProjectName}/` | sk.test | backend: `unit-test.md`, `integration-test.md`, `contract-test.md` · frontend/mobile: `component-test.md`, `contract-test.md` |
| `06-uat/` | sk.uat | `acceptance-result.md`, `user-flow-test.md`, `signoff.md` |
| `07-security-audit/` | sk.security-audit | `owasp-report.md`, `stride-review.md`, `dependency-scan.md`, `security-signoff.md` |

`{ProjectName}` always matches a `project` name in `memory/projects/index.md`.

---

## 3. Path Resolution (use this everywhere)

```
STORY_DIR  = specs/STORY-{ID}-{feature-name}/
PHASE_DIR  = STORY_DIR/{NN-phase}/
PROJECT_PHASE_DIR = STORY_DIR/{NN-phase}/{ProjectName}/   # for 03/04/05
```

Resolve the active story in this order:
1. `session.yaml` → `story_dir` (absolute-from-root path written by `sk.session` / `sk.story`).
   If present, use it verbatim.
2. Else `session.yaml` → `active_story_id` (e.g. `STORY-001`): glob `specs/STORY-{id}-*/` and
   take the single match.
3. Else (no active story) STOP and instruct: run `sk.session start` or `sk.story` first.

When a skill creates or first resolves the story folder, it MUST write both `active_story_id`
and `story_dir` back to `session.yaml` so downstream skills resolve unambiguously.

**Next STORY id:** glob `specs/STORY-*/`, parse the numeric segment, take `max + 1`,
zero-pad to 3 digits. If none exist, start at `001`. (Also scan legacy
`specs/intents/**/story-*.md` ids so a migrated repo never reuses a number.)

---

## 4. Project scoping (03 / 04 / 05)

Planning, implementation, and testing are **project-scoped**: one subfolder per participating
project, named by its `memory/projects/index.md` entry. A single story may touch multiple
projects (e.g. `Backend.API` + `Customer.Web`). Skills determine participating projects from:
- explicit `--project {ProjectName}` flag, else
- the per-project design files written under `02-design/projects/`, else
- `memory/projects/index.md` filtered by the `--role` flag's type
  (`backend` role → `backend`/`library`; `frontend` role → `frontend`/`mobile`).

A project's `type` selects which files a phase emits (see the phase→file map for 05-test).

---

## 5. Branch & Session Convention

- **Default base branch:** `dev`. Allow override to the current branch or a custom name.
- **Branch name:** `feature/{story-id}/{feature-name}-{YYYYMMDD}`
  - Example: `feature/STORY-001/customer-login-20260624`
  - Sanitize each segment: lowercase, spaces → hyphens, strip punctuation.
- **One feature branch == one independent story.** A story may span multiple projects and a
  session may carry multiple roles, but the branch maps 1:1 to the story.
- The active story is always the working focus for the session.

---

## 6. Backward Compatibility & Migration

The legacy layout was `specs/intents/{intent}/units/{unit}/stories/{story-id}/...`. It MUST
keep working.

**Detection.** A repo is "legacy" if `specs/intents/` contains `story-*.md` files and the
target story has no `specs/STORY-*/` folder.

**Read path.** When resolving a story that exists only under the legacy layout, read it in
place — never error because the new folder is absent.

**Migration (automatic, non-destructive).** When a lifecycle skill touches a legacy story,
offer/perform migration:
1. Create `specs/STORY-{ID}-{feature-name}/` (derive `{ID}`/slug from the legacy story
   frontmatter `id` + title).
2. **Copy** (do not move/delete) legacy artifacts into the matching phase folders:
   - `story-{ID}.md` → `01-story/story.md` (split acceptance criteria into
     `01-story/acceptance-criteria.md`; requirements into `01-story/requirement.md`).
   - `architecture.md` / `data-model.md` / `contracts/*` → `02-design/`.
   - `plan.md` / `tasks.yaml` → `03-plan/{ProjectName}/`.
   - existing reviews/audits → `04-implementation/` / `07-security-audit/` as applicable.
3. Preserve all original content verbatim; never delete user data. The legacy folder is left
   intact. To remove anything, use `.claude/hooks/archive-file.sh` (human review), never `rm`.
4. Record the migration in `session.yaml` (`migrated_from:` the legacy path) and report it.

If the user declines migration, skills continue to read/write the legacy paths for that story.

---

## 7. Idempotency rules (all skills, all phases)

- Create folders/files if absent; **update in place** if present — never wipe a folder.
- Preserve user-authored sections and notes not derived from the current run.
- Never delete a phase folder or project folder. Stale projects are noted, not removed.
- Merge registry rows (`projects/index.md`) by `project` name — no duplicates.
