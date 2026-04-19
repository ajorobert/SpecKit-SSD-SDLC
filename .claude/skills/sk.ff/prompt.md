# sk.ff — Fast Forward (Orchestrator)
Runs the SDLC pipeline from story capture through planning in one invocation.
Role: lead (orchestrator) | Level: story

This skill orchestrates other skills in sequence. Each sub-skill runs with its own
isolated context — state is passed via the file system (session.yaml + spec artifacts).

## Mode Detection
- `sk.ff` → [FEATURE MODE] full pipeline: specify → clarify → design → plan
- `sk.ff --bug` → [BUG MODE] fix pipeline: specify --bug → clarify → plan
  Architecture step is skipped in bug mode — the unit architecture already exists.
  If the bug fix requires a data model or contract change, stop and run sk.design --targeted manually.

## Pre-flight
1. Read session.yaml — verify system-context.md and tech-stack.md populated
   system-context.md missing: STOP — run sk.init first
   tech-stack.md missing: STOP — run sk.init first

## Orchestration: [FEATURE MODE]

### Phase 1 — Story Capture
Invoke skill: sk.specify
- Context injected: session.yaml, system-context.md, architecture-decisions.md, domain-model.md
- Waits for: story-{ID}.md written with checkpoint_mode set in frontmatter
- Reads back: active_story_id from session.yaml (updated by sk.specify)
- Reads back: checkpoint_mode from story-{ID}.md frontmatter

### Phase 2 — Clarification
Invoke skill: sk.clarify
- Context injected: session.yaml
- Waits for: story-{ID}.md updated with Clarifications section
- No checkpoint gate here — clarify always runs

### Phase 3 — Design [FEATURE MODE only]
Condition: checkpoint_mode = validate → invoke sk.design
           checkpoint_mode = standard or confirm → skip to Phase 4

If invoked:
- Invoke skill: sk.design
- sk.design auto-detects FRESH or RESUME mode and runs only phases needed for this unit
  (architecture always; data model and contracts only if unit stories signal the need)
- Gates inside sk.design are governed by checkpoint_mode per its own gate schedule
- Waits for: all needed design artifacts written (architecture.md at minimum)
- On sk.design completion: set story frontmatter checkpoint_status: approved

### Phase 4 — Implementation Plan
Invoke skill: sk.plan
- Context injected: session.yaml, tech-stack.md
- Waits for: sk.plan to complete (it manages its own checkpoint gate internally).

## Orchestration: [BUG MODE]

### Phase 1 — Bug Report Capture
Invoke skill: sk.specify --bug
- Same as feature mode Phase 1, bug framing

### Phase 2 — Clarification
Invoke skill: sk.clarify
- Focus clarify on: reproduction conditions, edge cases, regression risk

### Phase 3 — Implementation Plan (no architecture step)
Invoke skill: sk.plan
- Waits for: sk.plan to complete (it manages its own checkpoint gate).
- Verify story_type: bug in story frontmatter before proceeding

## Checkpoint Pause Protocol
When a checkpoint pause is required:
1. Display the pause message clearly
2. Write current state (session.yaml updated with active focus)
3. Wait for user input: 'approved' or 'cancel'
4. 'cancel': STOP pipeline, report artifacts created so far
5. 'approved': continue to next phase

## Completion Report
After all phases complete, display:
```
Fast Forward complete.
Story: {story-id} — {story title}
Mode: {FEATURE | BUG}

Artifacts created:
  ✓ story-{ID}.md         (sk.specify)
  ✓ story-{ID}.md         (sk.clarify — clarifications added)
  ✓ architecture.md       (sk.design — if validate checkpoint)
  ✓ plan.md               (sk.plan)

Next step: /sk.implement
```

## Output Artifacts
All artifacts from each invoked sub-skill.

## Quality Bar
- Checkpoint pauses respected — never skip an approval gate
- All artifacts created in correct locations
- Story frontmatter updated throughout (status, checkpoint_status)
- Bug mode: story_type: bug confirmed in frontmatter before plan proceeds
- Each sub-skill invocation is self-contained — no state leaks between phases
