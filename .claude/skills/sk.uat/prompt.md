# sk.uat
User Acceptance Testing against story acceptance criteria.
Role: frontend-qa | Level: story
Frontend only — backend uses sk.test for contract and integration tests.

## Step 0: Capability Pack Selection
Load platform packs before testing.

Resolve platform first (see Platform Detection below), then read:
- Always: `.claude/skills/accessibility-standards/SKILL.md`
- Platform = web → `.claude/skills/nextjs-patterns/SKILL.md`
- Platform = admin → `.claude/skills/react-admin-patterns/SKILL.md`
- Platform = mobile → `.claude/skills/react-native-patterns/SKILL.md`

List the packs loaded before continuing.

## Platform Detection
Resolve platform before loading context:
- `sk.uat --platform web` → browser-based (Next.js, React Admin)
- `sk.uat --platform mobile` → React Native device/simulator testing
- `sk.uat --platform admin` → browser-based admin portal (React Admin)
- No flag → ask user: "Which platform are you testing? (web / mobile / admin)"

Platform determines test tooling and test scenarios. Declare platform at start of execution.

## Pre-flight
1. Read session.yaml — resolve the active story via `.specify/memory/standards/story-lifecycle.md`
   §3 (`story_dir`). No active story → STOP: run sk.session/sk.story first.

## Context loading
- `STORY_DIR/01-story/acceptance-criteria.md`
  → each acceptance criterion (AC-n / Given-When-Then) becomes a UAT scenario. This file is the
    authoritative contract UAT validates against.
- `STORY_DIR/01-story/story.md` → user story + actor, for user-flow framing.
- `STORY_DIR/05-test/` → the frontend/mobile projects' `contract-test.md` (whichever frontend
    projects this platform maps to) → consumer expectations already covered, to avoid duplication.
    UAT is **platform-scoped** (web/mobile/admin), not project-scoped, so it reads across the
    relevant frontend projects rather than a single `{ProjectName}`.
  (Backward compat: legacy `story-{ID}.md` + `contracts/test-plan.md` read in place if present.)

## Test execution by platform

### web (Next.js)
- Tooling: Playwright or Cypress (per tech-stack.md)
- Scenarios: full browser E2E, user journey flows, responsive layout
- Run tests against acceptance criteria
- Report pass/fail per criterion

### mobile (React Native)
- Tooling: Maestro or Detox (per tech-stack.md)
  Note: no browser — do not use Playwright/Cypress for mobile
- Scenarios: device/simulator flows, offline behavior, deep links, push notification handling
- Run tests against acceptance criteria
- Report pass/fail per criterion

### admin (React Admin)
- Tooling: Playwright or Cypress (per tech-stack.md)
- Scenarios: CRUD operations, bulk actions, role-based visibility, data table pagination
- Run tests against acceptance criteria
- Report pass/fail per criterion

## Post-execution — Write `06-uat/` Artifacts (per story-lifecycle.md §2)
Map each finding to the acceptance criterion it relates to, then write three files under
`STORY_DIR/06-uat/` (create if absent, update in place per §7):

**`acceptance-result.md`** — per-criterion verdict:
```
# {STORY-ID} — UAT Acceptance Results  (platform: {web|mobile|admin})

| Criterion | Scenario | Result | Notes |
|-----------|----------|--------|-------|
| AC-1 | {…} | PASS/FAIL | {…} |

## Passed Scenarios
{list}

## Failed Scenarios
{list with reproduction + which AC}
```

**`user-flow-test.md`** — end-to-end journey walkthroughs (the actor's path through the feature),
each step with expected vs. actual and any UX/accessibility feedback.

**`signoff.md`** — approval record:
```
# {STORY-ID} — UAT Sign-off
Platform(s) tested: {…}
Approval Status: APPROVED | REJECTED | CONDITIONAL
User Feedback: {…}
Approver / Date: {…}
```

Update `STORY_DIR/01-story/story.md` frontmatter (legacy `story-{ID}.md` if that is the only copy):
- `test-status = pass` — if ALL acceptance criteria scenarios PASS for every tested platform.
- `test-status = fail` — if any AC scenario fails (record which criteria + platform in acceptance-result.md).

Note: if testing multiple platforms, all must pass before `test-status = pass`.

## Quality Bar
- Platform declared and correct tooling used
- Every acceptance criterion in 01-story/acceptance-criteria.md has a mapped result
- No acceptance criterion left unmapped
- Mobile platform never tested with browser tooling
- 06-uat/ contains acceptance-result.md, user-flow-test.md, signoff.md
- All AC-mapped scenarios must PASS before test-status = pass
