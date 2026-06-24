# Lifecycle Refactor — Final Audit

**Scope:** the full SpecKit lifecycle refactor to the **unit-anchored** enterprise SDLC structure
(Intent → Unit → `stories/` + numbered phase folders `02-design`…`07-security-audit`,
project-scoped 03/04/05).
**Canonical reference:** `.specify/memory/standards/story-lifecycle.md`.
**Method:** static verification of every skill's resolved paths, output file-sets, and cross-skill
contracts against the target tree.
**Final verdict:** ✅ **PASS — conformant and internally consistent.**

> History: an earlier iteration used a flat `specs/STORY-{ID}/` model (audited and fixed, then
> re-pivoted to this unit-anchored model on request). All flat-model artifacts have been removed
> from the skills; this document is the finalized audit of the current model.

---

## 1. Structure conformance — ✅

| Target node | Owner command | Resolved path | Status |
|---|---|---|---|
| `.specify/memory/projects/index.md` (router) | `sk.init` | `.specify/memory/projects/index.md` | ✅ |
| `.specify/memory/projects/{P}/{project,tech-stack,coding-standards}.md` | `sk.init` | ✅ | ✅ |
| `.specify/memory/standards/{api,data,observability}-standards.md` | `sk.init` | ✅ | ✅ |
| `intents/{NNN}-{name}/intent.md` | `sk.intent` *(new)* | `specs/intents/{intent-id}/intent.md` | ✅ |
| `units/{unit}/unit-brief.md` | `sk.unit` *(new)* | `UNIT_DIR/unit-brief.md` | ✅ |
| `stories/story-{Layer}-{INTENT}-{UNIT}-{NNN}.md` + `jira.md` | `sk.story` | `UNIT_DIR/stories/…` | ✅ one file per impacted layer; AC inside |
| `02-design/{architecture,impact-analysis,api-contract,database-design}.md` + `projects/{P}.md` | `sk.design` | `UNIT_DIR/02-design/…` | ✅ |
| `03-plan/{P}/{plan,tasks,checklist,jira-subtask,estimation}.md` | `sk.plan` | `UNIT_DIR/03-plan/{P}/…` | ✅ 5 files |
| `04-implementation/{P}/{implementation,progress,validation}.md` | `sk.implement` | `UNIT_DIR/04-implementation/{P}/…` | ✅ 3 files |
| `05-test/{P}/` backend→`unit/integration/contract`; frontend+mobile→`component/contract` | `sk.test` | `UNIT_DIR/05-test/{P}/…` | ✅ type-selected |
| `06-uat/{acceptance-result,user-flow-test,signoff}.md` | `sk.uat` | `UNIT_DIR/06-uat/…` | ✅ 3 files |
| `07-security-audit/{owasp-report,stride-review,dependency-scan,security-signoff}.md` | `sk.security-audit` | `UNIT_DIR/07-security-audit/…` | ✅ 4 files |

## 2. Anchor & resolution integrity — ✅
- `UNIT_DIR = specs/intents/{intent-id}/units/{unit}/` is the single lifecycle anchor; resolution
  via `session.yaml` `unit_dir` → `active_intent_id`+`active_unit_id` (story-lifecycle.md §3).
- **0** residual `STORY_DIR`, `01-story`, or `story_dir` tokens across all skills.
- **0** leftover sed artifacts (verbose placeholders cleaned).
- `active_story_id` correctly scopes only the *focused layer story* within a unit; resolver
  phrases and report labels use unit terms.
- Branch: `feature/{intent-id}/{unit}-{YYYYMMDD}`; base `dev`; one branch == one unit.
- Canonical doc is in sync with the project template copy.

## 3. Pipeline wiring — ✅
- Full chain: `sk.intent → sk.unit → sk.story → sk.design → sk.plan → sk.implement → sk.test →
  sk.uat → sk.security-audit`, each resolving `UNIT_DIR` and writing its phase folder.
- Orchestrator → sub-skill delegation writes into the same `UNIT_DIR` phase folders
  (sk.specify/clarify/architect-probe, architecture/datamodel/contracts/ui-design,
  planstory/analyze, tasks/scaffolding/codegen).
- Gate/aux skills migrated: verify, ship, review, ff, hotfix, rollback, investigate, migrate,
  perf, refactor, impact.
- `sk.ff` now has a Phase 0 that ensures intent/unit exist before invoking `sk.story` (closes the
  prerequisite gap introduced by making the unit the capture target).
- All 10 lifecycle skills inject the canonical `story-lifecycle.md`; no inject_files reference a
  potentially-missing file (`projects/index.md` is read at runtime).
- Contract source of truth standardized: `02-design/api-spec.json` (machine) + `api-contract.md`
  (human); consumers read the json.

## 4. Docs — ✅
- `CLAUDE.md` — "Unit Lifecycle" section + Tier-3 KB at `02-design/knowledge-base.md`.
- `README.md` — philosophy, quick-start, hierarchy, command list, and artifact reference updated
  to Intent → Unit → Story; `/sk.intent` and `/sk.unit` documented.

---

## Open items (non-blocking)

| # | Item | Severity | Note |
|---|---|---|---|
| 1 | **specs location** | confirm | Tree draws `specs/` under `.specify/`; implementation keeps **root** `specs/intents/…` (matches existing repo + `@specs/knowledge-base.md` import + prior explicit choice). One mechanical prefix change if `.specify/specs/` is truly intended. |
| 2 | `sk.hotfix` branch | cosmetic | Uses `hotfix/{story-id}` (incident-scoped) rather than the unit feature branch — intentional for P0 fixes; left as-is. |
| 3 | Additive frontmatter/files | none | `intent.md`/`unit-brief.md` carry richer frontmatter; `02-design/` also emits `api-spec.json`/`test-plan.md`; `04-implementation/` holds a working `tasks.yaml`. Support the pipeline; not deviations. |
| 4 | Live run | verification | This audit is static (paths, file-sets, wiring). A dry-run `sk.intent → … → sk.security-audit` on a sample feature would prove folders materialize exactly as drawn. |

## Backward compatibility
Pre-existing `specs/intents/{intent}/units/{unit}/` content (loose `architecture.md`,
`data-model.md`, `contracts/`, `stories/story-*.md`) and any earlier flat `specs/STORY-*/` folders
are read in place and never deleted; removal goes through `.claude/hooks/archive-file.sh`.

---

**Sign-off:** the lifecycle refactor meets the target structure and is internally consistent.
Only Item 1 (specs root vs `.specify/specs`) needs a user decision; everything else is complete.
