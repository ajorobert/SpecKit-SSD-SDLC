# sk.clarify
Resolves ambiguities in the active story using a structured 5-question loop.
Role: po, architect, lead | Level: story

## Pre-flight
1. Read session.yaml active_story_id
   NULL → STOP: run sk.session focus --story {id} first
2. Load story-{ID}.md from:
   specs/intents/{intent}/units/{unit}/stories/{story-id}/story-{ID}.md

## Ambiguity scan
Perform a structured coverage scan across these categories.
For each category mark status: Clear / Partial / Missing.

- Functional scope: user goals, success criteria, explicit out-of-scope
- Domain & data model: entities, attributes, lifecycle/state transitions, scale assumptions
- Interaction & UX: critical user journeys, error/empty/loading states
- Non-functional: performance targets, reliability, observability, security/privacy, compliance
- Integration: external dependencies and their failure modes, protocol assumptions
- Edge cases: negative scenarios, rate limiting, conflict resolution
- Constraints: technical constraints, explicit tradeoffs, rejected alternatives
- Acceptance criteria: testability of each criterion, measurable Definition of Done
- Placeholders: TODO markers, ambiguous adjectives ("robust", "intuitive") lacking quantification

## Question loop (max 5 questions)
Generate an internal prioritized queue of up to 5 questions from Partial/Missing categories.
Only include questions whose answers materially impact architecture, data modeling,
task decomposition, test design, or compliance validation.

For each question:
1. Present EXACTLY ONE question at a time — never reveal the queue
2. For multiple-choice: state **Recommended:** option with 1-2 sentence rationale, then list options as table
3. For short-answer: state **Suggested:** answer with brief reasoning
4. After user answers: record in working memory, then immediately:
   - Append `- Q: <question> → A: <answer>` under `## Clarifications / ### Session YYYY-MM-DD` in story-{ID}.md
   - Apply the clarification to the appropriate section in story-{ID}.md (acceptance criteria, scope, constraints, etc.)
   - Save story-{ID}.md after each integration
5. Stop early if: all critical ambiguities resolved, user signals "done"/"proceed", or 5 questions reached

## After loop completes
- Final pass: confirm no [NEEDS CLARIFICATION] markers remain in story-{ID}.md
- If scope changed: flag to user and suggest updating story status

## Output Artifacts
story-{ID}.md (updated with clarifications inline)

## Quality Bar
- All ambiguities resolved or explicitly deferred before sk.plan proceeds
- No contradictory statements remain in the story
- Each clarification bullet is testable (no vague language)
- Total questions asked ≤ 5
