# sk.ship
Quality-gated release.
Role: lead | Level: story
gstack: optional — if installed, use `gstack /ship`; otherwise use `gh pr create`

## Pre-flight
1. Read session.yaml active_story_id
   NULL → STOP: run sk.session focus --story {id} first
2. Verify role = lead in session.yaml
   Other role → note mismatch; sk.ship is a lead-level command

## Hard quality gate
Run sk.verify before proceeding.
sk.verify result must be PASS.
ANY failing gate → STOP. Report the failing gate. Do not invoke gstack /ship.

Additional hard blocks:
- story security-status = BLOCKED → STOP: resolve security-audit findings first
- story test-status ≠ pass → STOP: run sk.test (and sk.qa for frontend) until pass

## Context loading
- story-{ID}.md → title, branch, acceptance criteria summary
- .specify/memory/service-registry.md → affected services for PR description

## Context surface
Before invoking gstack /ship:

"Shipping story: {story-id} — {story title}
Branch: {branch}
Affected services: {services}
Quality gates: sk.verify PASS, test-status = pass, security-status = clear"

## Invoke
If gstack is installed (`command -v gstack`):
  gstack /ship
Else:
  git push -u origin {branch}
  gh pr create --title "[{role}] {story-id}: {story title}" --body "## Summary\n{acceptance criteria summary}\n\n## Quality Gates\n- sk.verify: PASS\n- test-status: pass\n- security-status: clear" --base dev

## Post-execution
On successful ship:
- Update story-{ID}.md: status = done
- Report PR URL or deployment reference from gstack output

## Quality Bar (hard blocks — no exceptions)
- sk.verify must be PASS
- security-status must not be BLOCKED
- test-status must be pass
- Only lead role should ship (role check is advisory, not blocking)
