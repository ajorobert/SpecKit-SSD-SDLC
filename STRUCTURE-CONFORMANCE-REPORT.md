# Structure Conformance Report — Unit-Anchored Lifecycle

**Question:** does the current implementation meet the target tree (Intent → Unit → `stories/` +
numbered phase folders, project-scoped 03/04/05)?
**Method:** static verification of every skill's resolved paths and output file-sets against the
target tree.
**Verdict:** ✅ **MEETS REQUIREMENT.** Every node in the target tree maps to a command that writes
it at the correct path. One assumption (specs location) and a few cosmetic notes below.

---

## 1. Memory layer (`.specify/memory/`) — ✅

| Target | Owner | Status |
|---|---|---|
| `projects/index.md` (router `project \| type \| code-root`) | `sk.init` | ✅ |
| `projects/{ProjectName}/{project,tech-stack,coding-standards}.md` | `sk.init` | ✅ |
| `standards/{api,data,observability}-standards.md` | `sk.init` | ✅ |
| `standards/story-lifecycle.md` (canonical reference) | present + injected | ✅ |

## 2. Spec layer — Intent → Unit → lifecycle — ✅

| Target node | Command | Resolved output | Status |
|---|---|---|---|
| `intents/{NNN}-{name}/intent.md` | **`/sk.intent`** (new) | `specs/intents/{intent-id}/intent.md` | ✅ |
| `units/{unit}/unit-brief.md` | **`/sk.unit`** (new) | `UNIT_DIR/unit-brief.md` | ✅ |
| `stories/story-{Layer}-{INTENT}-{UNIT}-{NNN}.md` + `jira.md` | `/sk.story` | `UNIT_DIR/stories/…` | ✅ (one file per impacted layer; AC inside) |
| `02-design/{architecture,impact-analysis,api-contract,database-design}.md` + `projects/{P}.md` | `/sk.design` | `UNIT_DIR/02-design/…` | ✅ |
| `03-plan/{P}/{plan,tasks,checklist,jira-subtask,estimation}.md` | `/sk.plan` | `UNIT_DIR/03-plan/{P}/…` | ✅ (5 files) |
| `04-implementation/{P}/{implementation,progress,validation}.md` | `/sk.implement` | `UNIT_DIR/04-implementation/{P}/…` | ✅ (3 files) |
| `05-test/{P}/` backend→`unit/integration/contract`; frontend+mobile→`component/contract` | `/sk.test` | `UNIT_DIR/05-test/{P}/…` | ✅ (type-selected) |
| `06-uat/{acceptance-result,user-flow-test,signoff}.md` | `/sk.uat` | `UNIT_DIR/06-uat/…` | ✅ (3 files) |
| `07-security-audit/{owasp-report,stride-review,dependency-scan,security-signoff}.md` | `/sk.security-audit` | `UNIT_DIR/07-security-audit/…` | ✅ (4 files) |

## 3. Anchor & resolution consistency — ✅
- Canonical `story-lifecycle.md` defines `UNIT_DIR = specs/intents/{intent-id}/units/{unit}/` as
  the lifecycle anchor; resolution via `unit_dir` → `active_intent_id`+`active_unit_id`.
- Repo-wide sweep: **0** residual `STORY_DIR`, `01-story`, or `story_dir` references in skills.
- `active_story_id` now correctly scopes only the *focused layer story* within a unit (not the
  lifecycle container). Resolver phrases and report labels corrected to unit terms.
- Branch convention: `feature/{intent-id}/{unit}-{YYYYMMDD}` (e.g.
  `feature/001-authentication/login-20260624`); base `dev`. One branch == one unit.
- Project-scoping (03/04/05) and the per-type 05-test split match the tree exactly.

## 4. Pipeline wiring — ✅
`/sk.intent → /sk.unit → /sk.story → /sk.design → /sk.plan → /sk.implement → /sk.test → /sk.uat
→ /sk.security-audit`. Orchestrators delegate to sub-skills that write into the same `UNIT_DIR`
phase folders (sk.specify/clarify/architect-probe, architecture/datamodel/contracts/ui-design,
planstory/analyze, tasks/scaffolding/codegen). Gate skills (verify/ship/review/ff/hotfix/rollback/
investigate/migrate/perf/refactor/impact) resolve `UNIT_DIR` and read/write the phase folders.
Docs (CLAUDE.md, README.md) updated to the unit-anchored model.

---

## Assumption to confirm
- **specs location:** the target tree draws `specs/` nested under `.specify/`. The implementation
  keeps `specs/` at the **repo root** (`specs/intents/…`), consistent with the existing repo,
  CLAUDE.md's `@specs/knowledge-base.md` import, and the user's earlier explicit "root specs/"
  choice. Mechanical to flip if `.specify/specs/` is truly intended.

## Cosmetic / non-blocking notes
- `intent.md` / `unit-brief.md` carry richer frontmatter than the bare tree shows (id, code,
  impacted_projects) — additive, not a deviation.
- `02-design/` also emits `api-spec.json` (machine contract) and `test-plan.md` alongside
  `api-contract.md`; `04-implementation/` also holds a working `tasks.yaml`. These support the
  pipeline and don't conflict with the tree.
- Backward-compat: pre-existing flat `specs/STORY-*/` (earlier iteration) and loose
  `units/{unit}/{architecture,data-model}.md` are read in place; never deleted.

## Caveat
This is static verification of prompt/spec text (paths, file-sets, cross-skill wiring), not a live
pipeline run. A dry-run of `/sk.intent → … → /sk.security-audit` on a sample feature would confirm
the folders materialize exactly as drawn.
