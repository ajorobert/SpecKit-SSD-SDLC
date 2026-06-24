# sk.plan — Implementation Planning (Orchestrator)
Orchestrates technical planning for the active story, **project-scoped** by role/project.
Role: lead (orchestrator) | Level: story

This skill prepares a planning brief, plans each impacted project (one plan per project), and
runs `sk.analyze` to catch cross-project conflicts. Output goes to `STORY_DIR/03-plan/{ProjectName}/`.

## Invocation Forms
- `sk.plan`                                    — plan the active story for ALL impacted projects
- `sk.plan --role {backend|frontend} --project {ProjectName}` — plan one project for one role
- `sk.plan --project {ProjectName}`            — plan one project (role inferred from its type)
- `sk.plan --analyze-only`                     — skip planning, just re-run analyze
- `sk.plan --refresh "{change}"`               — update brief with change, re-plan affected, analyze

## Role/Project Scoping (per story-lifecycle.md §4)
Resolve the **target project set**:
- `--project {ProjectName}` → exactly that project (must exist in `.specify/memory/projects/index.md`).
- else → every project with a `02-design/projects/{ProjectName}.md` impact file.
- `--role` filters/validates: `backend` → `backend`/`library` projects; `frontend` →
  `frontend`/`mobile` projects. If `--role` and `--project` types disagree, STOP and report.

## Pre-flight
1. Read session.yaml — resolve the active story via story-lifecycle.md §3 (`story_dir`).
   No active story: STOP — run sk.session/sk.story first.
2. Verify `STORY_DIR/02-design/architecture.md` exists. Missing: STOP — run sk.design first.
3. Read `STORY_DIR/02-design/impact-analysis.md` + `02-design/projects/*.md` for the impacted
   projects; read `.specify/memory/projects/index.md` for each project's `type`/`code-root`.
4. Read `STORY_DIR/01-story/` (story.md, requirement.md, acceptance-criteria.md) for scope.
5. Read `checkpoint_mode` from session.yaml.
   (Backward compat: if only legacy `specs/intents/**` artifacts exist, read them in place.)

## Mode Detection and Resume Logic
Determine mode based on arguments and existing files.

**TARGETED** (`--project {ProjectName}` [`--role …`])
- Skip Phase 0 (Planning Brief)
- Run Phase 1 only for that project (resume/overwrite existing)
- Run Phase 2 (Analyze) → Review Gate

**TARGETED** (`--analyze-only`)
- Skip Phase 0 and Phase 1 → Run Phase 2 (Analyze) → Review Gate

**REFRESH** (`--refresh "{change}"`)
- Run Phase 0 (Planning Brief) including the `{change}`
- Run Phase 1 only for projects affected by `{change}` → Phase 2 → Review Gate

**NORMAL / RESUME** (No flags)
- If `STORY_DIR/03-plan/planning-brief.md` is missing/empty: Run Phase 0.
- Let `P` be the target project set (all impacted projects).
- For any project in `P` missing `03-plan/{ProjectName}/plan.md`: Run Phase 1 for it.
- Run Phase 2 (Analyze) → Review Gate.

## Orchestration

### Phase 0 — Planning Brief
Condition: Run in NORMAL/RESUME if missing. Run in REFRESH.
1. Read `01-story/` + `02-design/` to identify cross-project commonalities.
2. Write `STORY_DIR/03-plan/planning-brief.md`:
   - **Recommended Execution Order**: sequence projects by dependency (e.g. backend contract
     before frontend consumer; shared library before its consumers).
   - **Shared Infrastructure Notes**: shared contracts, migrations, libraries.
   - **Cross-Project Dependencies**: explicit linkages between projects.
   *(In REFRESH mode, document the {change} and its impact here as well.)*

### Phase 1 — Per-Project Planning
Condition: Run for each project in the target set.
For each target project `{ProjectName}`, write `STORY_DIR/03-plan/{ProjectName}/` with five files
(invoke `sk.planstory` per project for the detailed plan; apply §7 idempotency):

- **`plan.md`** — implementation steps, approach, dependencies, architecture alignment.
- **`tasks.md`** — ordered developer tasks (granular, assignable).
- **`checklist.md`** — completion checklist (definition-of-done items, gates).
- **`jira-subtask.md`** — proposed Jira sub-tasks for this project (title + estimate + parent).
- **`estimation.md`** — estimated effort per task/total (story points or ideal-hours) + assumptions.

Context injected per project: `planning-brief.md`, `02-design/architecture.md`,
`02-design/database-design.md`, `02-design/api-contract.md`, `02-design/projects/{ProjectName}.md`,
`01-story/*`, and that project's `.specify/memory/projects/{ProjectName}/tech-stack.md` +
`coding-standards.md`.

### Phase 2 — Cross-Project Analysis
Condition: Always runs (except if pipeline aborted early).
Invoke skill: `sk.analyze`
- Context injected: all `02-design/` artifacts + every `03-plan/{ProjectName}/plan.md`.
- Waits for: Analyze report identifying any CRITICAL or HIGH cross-project findings.

### Phase 3 — Review Gate
If `checkpoint_mode` is `confirm` or `validate`, and any new plan was generating or analyze ran:
Display:
```
sk.plan | Review Gate  [checkpoint_mode: {mode}]

Planning Brief (if generated/updated):
  STORY_DIR/03-plan/planning-brief.md

Project Plans:
  {list all 03-plan/{ProjectName}/plan.md files just generated/updated}

Analyze Report:
  {Output from sk.analyze. If there are findings, highlight them.}

Check for:
  - Project plans do not contradict each other
  - Plans follow the 02-design/architecture.md requirements
  - No CRITICAL or HIGH findings in analyze report

Type 'approved' to mark ALL generated project plans as approved.
Type 'approved Backend.API Customer.Web' to approve specific projects.
Type 'cancel' to stop without updating statuses.
```
- Wait for user input.
- On approval: record `checkpoint_status: approved` for each approved project (in its
  `03-plan/{ProjectName}/checklist.md` header and the story `01-story/story.md` frontmatter).
- If `cancel`: leave statuses unchanged.
- If `checkpoint_mode` is `autopilot`, automatically approve all projects just planned.

## Completion Report
After pipeline completes, display:
```
sk.plan complete.
Story: {STORY-ID}

Projects planned:
  {list each {ProjectName} → 03-plan/{ProjectName}/ (5 files)}

Phases run:
  {Phase 0 (Planning Brief), Phase 1 (Projects: {list}), Phase 2 (Analyze)}

Next step: /sk.implement --project {ProjectName}   (role comes from the session)
```
