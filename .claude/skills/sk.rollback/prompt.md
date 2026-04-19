# sk.rollback
Revert a shipped story — automated or manual rollback plan.
Role: lead | Level: story

## Mode detection
- `sk.rollback --auto`   → [AUTO] generate git revert + migration rollback commands, execute on confirm
- `sk.rollback --plan`   → [PLAN ONLY] produce rollback-plan.md without executing anything
- `sk.rollback` (no flag) → ask user which mode
Declare mode at start.

## Pre-flight
1. Read session.yaml active_story_id
   NULL → ask user: "Which story ID are you rolling back?"
2. Resolve STORY_DIR: specs/intents/{intent}/units/{unit}/stories/{story-id}/
3. Read story-{ID}.md frontmatter:
   - status must be shipped or merged — WARN if not, ask explicit confirmation to proceed anyway
   - Record: branch, affected services, tags
4. Read plan.md (if exists) — identify what was changed
5. List migration files created during this story (check src/{service}/Migrations/ for timestamps matching story date range)
   Record: migration_files (may be empty)

## Context loading
1. .specify/memory/service-registry.md — identify dependent consumers of affected services
2. .specify/memory/standards/data-standards.md — rollback safety rules for migrations
3. .specify/memory/architecture-decisions.md

## Step 1 — Impact assessment
For each affected service and consumer:
- Is the change backwards-compatible? Can consumers tolerate the revert?
- Are there migration files? (→ data risk assessment required)
- Are there API contract changes? (→ consumer notification required)

Report:
- SAFE: revert is transparent to consumers
- WARN: consumers may need coordinated update
- BLOCK: data has been written in the new schema and rollback would cause data loss

On BLOCK: do NOT proceed. Report the specific data risk and stop. Suggest a forward-fix (sk.hotfix) instead.

## Step 2 — Rollback plan
Write rollback-plan.md covering:

### Code rollback
- Git revert commands (in order): `git revert {commit-sha} --no-edit`
- If merged via PR: `git revert -m 1 {merge-commit-sha}`
- Branch strategy: create revert branch or commit directly to main?

### Migration rollback (per migration file)
For each migration in migration_files:
- Rollback script location (from sk.migrate rollback-plan.md, if exists) OR generated inline
- Data loss annotation: SAFE / DATA LOSS: {what is lost}
- Execution order: migrations must roll back in reverse apply order

### Config / feature flag rollback (if applicable)
- List any config changes or feature flag toggles to revert

### Consumer coordination (if WARN)
- List services that must be notified or updated concurrently
- Recommended rollout order

### Verification steps
After rollback:
1. Smoke test: {key endpoint or behaviour to verify}
2. Check: dependent consumers responding normally
3. Confirm: no error spike in logs/observability

## Step 3 — [AUTO mode only] Execute
Display full rollback-plan.md.
Ask: "Execute this rollback now? This cannot be undone. (yes / no)"
Exact string "yes" required — any other input → STOP.

On "yes":
- Execute git revert commands
- Report each step as it completes
- STOP immediately on any failure and report state

## Step 4 — Post-rollback
After execution (auto) or at end of plan (plan-only):
1. Update story-{ID}.md status → rolled-back
2. Note: run sk.specify --bug to capture a bug story for the root cause, if not already done

## Output Artifacts
specs/intents/{intent}/units/{unit}/stories/{story-id}/rollback-plan.md
story-{ID}.md status updated (auto mode only)

## Quality Bar
- Every migration in the story accounted for with explicit DATA LOSS annotation
- BLOCK condition surfaced before any execution
- [AUTO] mode requires exact "yes" confirmation — no default execution
- Rollback plan includes consumer coordination if WARN
- Verification steps are story-specific, not generic
