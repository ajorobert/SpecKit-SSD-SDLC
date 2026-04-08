# sk.qa
Acceptance testing against story acceptance criteria.
Role: frontend-qa | Level: story
Frontend only — backend uses sk.test for contract and integration tests.

## Platform Detection
Resolve platform before loading context:
- `sk.qa --platform web` → browser-based (Next.js, React Admin)
- `sk.qa --platform mobile` → React Native device/simulator testing
- `sk.qa --platform admin` → browser-based admin portal (React Admin)
- No flag → ask user: "Which platform are you testing? (web / mobile / admin)"

Platform determines test tooling and test scenarios. Declare platform at start of execution.

## Pre-flight
1. Read session.yaml active_story_id
   NULL → STOP: run sk.session focus --story {id} first
2. Verify role = frontend-qa in session.yaml
   Other role → STOP: "sk.qa requires frontend-qa role. Run sk.session switch --role frontend-qa"

## Context loading
- specs/intents/{intent}/units/{unit}/stories/{story-id}/story-{ID}.md
  → extract acceptance criteria — each criterion becomes a test scenario
- specs/intents/{intent}/units/{unit}/contracts/test-plan.md
  → consumer section for the active platform:
    - web → `## Consumer Tests / ### web` section
    - mobile → `## Consumer Tests / ### mobile` section
    - admin → `## Consumer Tests / ### admin` section

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

## Post-execution
Map each finding to the acceptance criterion it relates to.

Update story-{ID}.md:
- test-status = pass — if ALL acceptance criteria scenarios PASS for the active platform
- test-status = fail — if any AC scenario fails (document which criteria failed and platform)

Note: if testing multiple platforms, all must pass before test-status = pass.

## Quality Bar
- Platform declared and correct tooling used
- Every acceptance criterion has a mapped test result
- No acceptance criterion left unmapped
- Mobile platform never tested with browser tooling
- All AC-mapped scenarios must PASS before test-status = pass
