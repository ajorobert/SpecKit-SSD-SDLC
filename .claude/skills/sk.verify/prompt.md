# sk.verify
PASS/FAIL quality gate for active story.
Role: architect | Level: story

**When to run:** After sk.test passes (test-status = pass in story frontmatter), before sk.ship.
This is the final gate — not a mid-implementation check. Run sk.plan --analyze-only if you need a
consistency check earlier in the cycle (before implementation starts).

## Step 0: Capability Pack Selection
Load all packs applicable to this story for comprehensive gate evaluation.

1. Read session.yaml → get `active_story_id` and `role`; resolve `STORY_DIR` per
   `.specify/memory/standards/story-lifecycle.md` §3 (`story_dir`).
2. Read story frontmatter (`STORY_DIR/01-story/story.md`) → check `tags` array
3. Read ALL applicable packs for the story's role and domain. **Load ≤6 packs total.**

Backend story: always `.claude/skills/backend-feature-patterns/SKILL.md`
Frontend story: always `.claude/skills/frontend-design-system/SKILL.md`, `.claude/skills/accessibility-standards/SKILL.md`

Then conditional packs per the CLAUDE.md Tech Stack Context Skills table matching the story tags.

List the packs loaded before continuing.

## Input Artifacts (per story-lifecycle.md — all under STORY_DIR)
STORY_DIR/01-story/ (story.md + frontmatter, requirement.md, acceptance-criteria.md)
STORY_DIR/02-design/ (architecture.md, database-design.md, api-spec.json/api-contract.md)
STORY_DIR/03-plan/{Project}/ (plan.md, tasks.md, checklist.md) — per impacted project
STORY_DIR/04-implementation/{Project}/ (implementation.md, progress.md, validation.md, tasks.yaml)
STORY_DIR/05-test/{Project}/ + STORY_DIR/06-uat/ + STORY_DIR/07-security-audit/
.specify/memory/architecture-decisions.md
.specify/memory/standards/ (all files)
.claude/skills/governance/quality-gates.md
Rubric blocks from:
  .claude/skills/sk.story/SKILL.md (rubric: story-completeness)
  .claude/skills/sk.test/SKILL.md  (rubric: test-coverage)
  .claude/skills/sk.security-audit/SKILL.md (rubric: security-coverage)
(Backward compat: legacy `specs/intents/**` artifacts evaluated in place if no STORY_DIR.)

## Steps
1. Read quality-gates.md — evaluate all applicable gates
2. Spec Gate: always evaluate `01-story/`; also apply `story-completeness` rubric from sk.story
3. Architecture Gate: evaluate if `02-design/architecture.md` exists
4. Plan Gate: evaluate if `03-plan/{Project}/plan.md` exists for every impacted project
5. Implementation Gate: evaluate if `04-implementation/{Project}/` tasks complete (tasks.yaml /
   progress.md all done) and validation.md passes, for every impacted project
6. Test Gate: apply `test-coverage` rubric from sk.test against `05-test/{Project}/`
7. Security Gate: apply `security-coverage` rubric against `07-security-audit/security-signoff.md`
8. Output structured report with PASS/FAIL per gate AND per rubric check
9. Overall PASS → story status set to done and verify-status=PASS via Stop hook
   Overall FAIL → status unchanged, verify-status=FAIL, list failures

## Output Artifacts
Verification report (displayed, not written to file)
STORY_DIR/01-story/story.md status updated if overall PASS
…/story.md verify-status field set to PASS or FAIL (written by Stop hook)

## Quality Bar
- Every gate item explicitly PASS, FAIL, or SKIP with reason
- FAIL items include specific finding not generic message
- Recommendations actionable not vague

## Completion Signal
Last line of output must be exactly one of:
`SK_RESULT: PASS` — overall verdict is PASS
`SK_RESULT: FAIL` — one or more gates failed
