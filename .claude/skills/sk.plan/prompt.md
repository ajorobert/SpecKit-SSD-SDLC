# sk.plan — Implementation Planning (Orchestrator)
Orchestrates technical planning for stories within a unit, resolving cross-story dependencies.
Role: lead (orchestrator) | Level: unit

This skill orchestrates two internal sub-skills. It prepares a planning brief, invokes `sk.planstory` for each specified story, and runs `sk.analyze` at the end to catch cross-story conflicts.

## Invocation Forms
- `sk.plan`                        — plan all `specified` stories missing plan.md
- `sk.plan --story {id}`           — skip brief generation, plan exactly one story
- `sk.plan --analyze-only`         — skip all planning, just re-run analyze
- `sk.plan --refresh "{change}"`   — update brief with change, re-plan affected, analyze

## Pre-flight
1. Read session.yaml — verify `active_unit_id` is set
   Missing: STOP — run sk.session focus --unit {unit-id} first
2. Verify architecture.md exists in the unit directory
   Missing: STOP — run sk.design first
3. Read all `story-{ID}.md` files in the unit directory. Note their `status`.
4. Read `checkpoint_mode` from session.yaml.

## Mode Detection and Resume Logic
Determine mode based on arguments and existing files.

**TARGETED** (`--story {id}`)
- Skip Phase 0 (Planning Brief)
- Run Phase 1 only for `{id}` (resume/overwrite existing)
- Run Phase 2 (Analyze)
- Enter Review Gate

**TARGETED** (`--analyze-only`)
- Skip Phase 0 and Phase 1
- Run Phase 2 (Analyze)
- Enter Review Gate

**REFRESH** (`--refresh "{change}"`)
- Run Phase 0 (Planning Brief) including the `{change}`
- Run Phase 1 only for stories affected by `{change}`
- Run Phase 2 (Analyze)
- Enter Review Gate

**NORMAL / RESUME** (No flags)
- If `planning-brief.md` is missing, or is empty: Run Phase 0
- Let `S` be the set of stories with `status: specified`.
- If any story in `S` is missing `plan.md`: Run Phase 1 for those missing stories.
- Run Phase 2 (Analyze)
- Enter Review Gate

## Orchestration

### Phase 0 — Planning Brief
Condition: Run in NORMAL/RESUME if missing. Run in REFRESH.
1. Read all stories in the unit to identify commonalities.
2. Write `specs/intents/{intent}/units/{unit}/planning-brief.md`:
   - **Recommended Execution Order**: sequence stories based on dependencies.
   - **Shared Infrastructure Notes**: e.g., "story 1 implements Redis; stories 3 & 4 depend on it"
   - **Cross-story Dependencies**: list explicit linkages.
   *(In REFRESH mode, document the {change} and its impact here as well).*

### Phase 1 — Story Planning
Condition: Run for stories determined by Mode Detection.
For each target story `{id}`:
Invoke skill: `sk.planstory`
- Context injected: `planning-brief.md`, `architecture.md`, `data-model.md`, `api-spec.json`, `story-{ID}.md`, `tech-stack.md`
- Waits for: `plan.md` written in the story's directory.
- *(Subagents run sequentially or in parallel, but isolated from each other.)*

### Phase 2 — Cross-Artifact Analysis
Condition: Always runs (except if pipeline aborted early).
Invoke skill: `sk.analyze`
- Context injected: all unit artifacts, all story `plan.md` files.
- Waits for: Analyze report (read-only output) identifying any CRITICAL or HIGH findings.

### Phase 3 — Review Gate
If `checkpoint_mode` is `confirm` or `validate`, and any new plan was generating or analyze ran:
Display:
```
sk.plan | Review Gate  [checkpoint_mode: {mode}]

Planning Brief (if generated/updated):
  specs/intents/{intent}/units/{unit}/planning-brief.md

Story Plans:
  {list all plan.md files that were just generated/updated}

Analyze Report:
  {Output from sk.analyze. If there are findings, highlight them.}

Check for:
  - Plans do not contradict each other
  - Plans follow the architecture.md requirements
  - No CRITICAL or HIGH findings in analyze report

Type 'approved' to mark ALL generated plans as approved.
Type 'approved story-001 story-002' to approve specifically.
Type 'cancel' to stop without updating statuses.
```
- Wait for user input.
- On approval: For each approved story, set its frontmatter `checkpoint_status: approved`.
- If `cancel`: leave `checkpoint_status` unchanged.
- If `checkpoint_mode` is `autopilot`, automatically approve all stories just planned.

## Completion Report
After pipeline completes, display:
```
sk.plan complete.
Unit: {unit-id}

Phases run:
  {list phases: Phase 0 (Planning Brief), Phase 1 (Stories: {list}), Phase 2 (Analyze)}

Next step: /sk.implement
```
