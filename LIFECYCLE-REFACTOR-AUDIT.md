# Lifecycle Refactor — Implementation Audit

> **STATUS: ALL ISSUES RESOLVED** (follow-up fix pass). H1, H2, M1–M5, and L1–L6 are fixed, plus
> the related legacy-path skills surfaced during verification (sk.knowledge-base, sk.migrate,
> sk.perf, sk.refactor, sk.impact, and all design/plan/implement sub-skills). Path resolution is
> now uniform through `story-lifecycle.md`; every legacy `specs/intents/**` reference that remains
> is explicitly tagged as a backward-compat fallback or legacy-mode-only step. See the per-item
> "✅ Fixed" notes below.


**Scope:** the enterprise STORY-lifecycle refactor (canonical `story-lifecycle.md` + `sk.init`,
`sk.story`, `sk.design`, `sk.plan`, `sk.implement`, `sk.test`, `sk.uat`, `sk.security-audit`,
`sk.session`, `CLAUDE.md`, `README.md`).
**Method:** static review of skill prompts/frontmatter against the canonical doc and cross-skill
contracts. Line refs are `file:line` at audit time.

**Verdict:** the per-phase folder/file *contracts* match the target tree, but there are **2 high-severity
correctness bugs** and several consistency gaps that mean the pipeline does not yet produce the new
structure end-to-end.

---

## HIGH

### H1 — Double `STORY-` prefix in folder/path construction
**✅ Fixed:** standardized `{ID}`=number, `active_story_id`=`STORY-{ID}`,
`STORY_DIR=specs/{active_story_id}-{slug}/`; removed the second prefix in story-lifecycle.md §2/§3,
sk.story, sk.session (with an explicit "never prepend a second STORY-" note).

The story id is defined *with* the `STORY-` prefix, but the folder path *prepends another* `STORY-`.

- `sk.story/prompt.md:30` — "zero-pad to 3 (`STORY-001`, `STORY-002`…)" → id **includes** `STORY-`.
- `sk.story/prompt.md:32` — `STORY_DIR = specs/STORY-{ID}-{feature-name}/` → with `{ID}=STORY-001`
  this yields `specs/STORY-STORY-001-{name}/`.
- `sk.session/prompt.md:45` — id = `STORY-{NNN}`; `:59` — `specs/STORY-{story-id}-{feature-name}/`
  → same double prefix.
- `story-lifecycle.md` is itself ambiguous: `{ID}` = "zero-padded sequence, e.g. `001`" (`:62`) and
  folder = `STORY-{ID}-…` (`:48,52,93`) → number only; **but** `:101` resolves via
  `active_story_id` (e.g. `STORY-001`) with glob `specs/STORY-{id}-*/` → `specs/STORY-STORY-001-*`.

**Impact:** folders created as `STORY-STORY-001-…` while resolution globs `specs/STORY-{id}-*` (or vice
versa) → create/resolve mismatch; downstream skills can't find the story.
**Fix:** pick ONE convention. Recommended: `{ID}` = number (`001`); folder = `STORY-{ID}-{slug}`;
`active_story_id = STORY-{ID}`; path resolution = `specs/{active_story_id}-{slug}/` (never re-prepend
`STORY-`). Update `story-lifecycle.md` §2/§3, `sk.story:30,32`, `sk.session:45,59` to be uniform.

### H2 — Orchestrators delegate file-writing to sub-skills that still write legacy paths
**✅ Fixed:** every sub-skill (specify/clarify/architect-probe, architecture/datamodel/contracts/
ui-design, planstory/analyze, tasks/scaffolding/codegen) now resolves `STORY_DIR` and writes into
its phase folder, with a legacy fallback. sk.planstory emits all five plan files per project;
sk.analyze is story/project-scoped.

Every refactored orchestrator delegates the actual artifact writing to sub-skills that were **not**
updated and still target `specs/intents/{intent}/units/{unit}/…`:

- `sk.story` → `sk.specify`, `sk.clarify`, `sk.architect-probe` (all contain `specs/intents`).
- `sk.design` → `sk.architecture`, `sk.datamodel`, `sk.contracts`, `sk.ui-design` (all legacy).
- `sk.plan` → `sk.planstory`, `sk.analyze` (legacy). `sk.plan` says "invoke `sk.planstory` per
  project" but `sk.planstory` writes `plan.md` into the legacy story dir.
- `sk.implement` → `sk.tasks`, `sk.scaffolding`, `sk.codegen` (legacy `tasks.yaml`/story dir).

**Impact:** running the pipeline produces a **mix** — orchestrator-owned "materialize/output-contract"
steps write some new phase files (e.g. `sk.story` Phase 7 → `01-story/`), while delegated content
(plans, contracts, data-model, tasks) lands in `specs/intents/**`. The new `02-design/`, `03-plan/`,
`04-implementation/` folders are only partially populated.
**Fix:** update the sub-skills' output paths to the resolved `STORY_DIR/{phase}` (passed down by the
orchestrator), or move the file-writing into the orchestrators. This is the "sub-skill sweep" flagged
during implementation.

---

## MEDIUM

> **✅ All MEDIUM fixed.** M1 — sk.design phase-need detection, gate messages, Phase 5 guide,
> Phase 6 UI, and completion report now use `02-design/` + story framing. M2 — all seven gate
> skills (verify/ship/review/ff/hotfix/rollback/investigate) migrated (prompts + SKILL.md
> descriptions); sk.verify evaluates `01..07` per project. M3 — `02-design/api-spec.json` is the
> machine source of truth, `api-contract.md` its human summary, all consumers read the json. M4 —
> sk.implement now has an outermost dependency-ordered per-project loop. M5 — branch keeps
> `{active_story_id}` verbatim, lowercasing only `{feature-name}`.

### M1 — `sk.design` is internally split between new and legacy paths
Pre-flight + Phase 0b + Output Contract use `02-design/`, but Phases 1–6 still use unit constructs:
- `:57` "Read all stories in the unit"; `:257,259` write `guide.yaml` under
  `specs/intents/{intent}/units/{unit}/`; `:174,175,204,298,314` gate messages cite legacy paths;
  `:269,282` rely on `unit-brief.md`/`active_unit_id`.

**Impact:** the architect sees contradictory paths; guide/KB indexing still points at the legacy tree.
**Fix:** rewrite Phases 1–6 gate/guide references to `STORY_DIR/02-design/…`; decide whether `guide.yaml`
still lives at unit level or moves under the story.

### M2 — Downstream gate skills not migrated (verify / ship / review / ff / hotfix / rollback / investigate)
These still read `specs/intents/**`, `story-{ID}.md`, `security-audit.md`, `test-plan.md`
(confirmed in each skill's `prompt.md`/`SKILL.md`).

**Impact:** `/sk.verify` (the 6 quality gates) and `/sk.ship` look for artifacts in the old locations
and won't find the new `05-test/`, `06-uat/`, `07-security-audit/` outputs → false FAILs or stale reads.
`/sk.ff` chains story→design→plan and will inherit H1/H2. README still documents the 6 gates unchanged.
**Fix:** migrate these to resolve via `story-lifecycle.md`, or scope the refactor explicitly and note
the gate skills as "legacy-path" until done.

### M3 — Contract file-name drift: `api-contract.md` vs `api-spec.json`
`sk.design` now writes `02-design/api-contract.md` and treats `api-spec.json` as optional
(`sk.design:29,37`), but consumers still key off `api-spec.json`:
- `sk.test:62`, `sk.security-audit:10` read "`api-contract.md` (+ api-spec.json)";
- `sk.design:227,281` (Phase 3/6) still emit/read `contracts/api-spec.json`.

**Impact:** contract tests/audits expect a machine-readable `api-spec.json` that the new design phase no
longer guarantees → endpoints-without-coverage flags, or tooling reads a missing file.
**Fix:** decide the source of truth. Recommended: keep `api-spec.json` as the machine contract emitted
into `02-design/`, with `api-contract.md` as its human summary; make all consumers read the json.

### M4 — `sk.implement` has no multi-project loop
Pre-flight resolves a project **set** (`sk.implement:22`) but Orchestration + `PROJECT_IMPL_DIR`
(`:23`) are singular and never iterate.
**Impact:** `sk.implement` with no `--project` and multiple impacted projects is undefined — likely
processes one or errors.
**Fix:** either require `--project`, or add an explicit "for each target project" loop around Phases 0–2.

### M5 — Branch case vs folder/id case mismatch
`sk.session:41,52` sanitize every branch segment to lowercase → `feature/story-001/{slug}-{date}`,
while the folder/id is `STORY-001` and `story-lifecycle.md:120`(§5) example shows
`feature/STORY-001/customer-login-20260624` (uppercase).
**Impact:** cosmetic/inconsistent; tooling that parses the story id back out of the branch (e.g.
`sk.session restore:79`) may not match the `STORY-` folder.
**Fix:** keep the `{story-id}` segment verbatim (`STORY-001`); lowercase only the `{feature-name}`.

---

## LOW

> **✅ All LOW fixed.** L1 — `projects/index.md` removed from inject_files (read at runtime, per the
> documented session.yaml pattern). L2 — sk.uat documented as platform-scoped, reads across the
> relevant frontend projects. L3 — sk.implement appends `projects_touched`; sk.session end derives it
> from `04-implementation/` if empty. L4 — JIRA two-story mints two consecutive STORY ids/folders
> tracked in `stories_touched`. L5 — tier-3 KB now lives at `02-design/knowledge-base.md`. L6 —
> sk.plan hint corrected to `/sk.implement --project {ProjectName}`.

- **L1 — inject_files may reference not-yet-existing files.** `projects/index.md` is injected by
  `sk.design/plan/implement/test/security-audit` SKILL.md but only exists after `sk.init`. In a fresh
  repo (or template project where `story-lifecycle.md` lives only under `templates/`), injecting a
  missing file can warn/fail on skill load. Guard or document the `sk.init`-first ordering.
- **L2 — `sk.uat` uses unresolved `{ProjectName}`.** `sk.uat` context loading references
  `05-test/{ProjectName}/contract-test.md` but UAT is platform-scoped with no `--project`/ProjectName
  resolution. Drop the project ref or resolve it from impacted frontend projects.
- **L3 — `projects_touched` never updated.** `sk.session end` commits "across {projects_touched}" but
  no skill writes `projects_touched` when a project is planned/implemented/tested → empty in the message.
- **L4 — JIRA two-story mode vs single STORY_DIR.** `sk.story` Phase 1 emits two sibling stories, but
  the session has one `active_story_id`/`story_dir`; Phase 7 says "each gets its own STORY_DIR" without
  defining how two folders/ids are minted and tracked in one session.
- **L5 — Tier-3 KB has no home in the new structure.** `CLAUDE.md` claims new stories "carry KB notes in
  their STORY folder", but no phase/skill writes a per-story knowledge-base file; `sk.knowledge-base`
  still targets `specs/intents/**`.
- **L6 — `sk.plan` completion hint.** Suggests `/sk.implement --role {role} --project {P}`, but
  `sk.implement` takes role from the session, not a flag — mildly misleading.

---

## What is correct (no action)
- Per-phase folder + filename contracts match the target tree for all 7 phases and the project memory
  layer (`projects/index.md` router + per-project files + shared standards). Verified previously.
- `sk.init` project detection (incl. `library` type), router format, and shared standards generation.
- Backward-compat **read** posture and non-destructive migration intent are stated consistently.
- Idempotency rules referenced uniformly via `story-lifecycle.md §7`.

---

## Recommended fix order
1. **H1** (mechanical, repo-wide id/path normalization) — unblocks correct folder creation/resolution.
2. **H2** (sub-skill output-path sweep) — makes the pipeline actually populate the new folders.
3. **M3** then **M1/M2** — align contract file + design/gate skills so verify/ship pass.
4. **M4/M5**, then **L1–L6**.
