# sk.plan
Creates technical implementation plan for a story.
Role: lead | Level: story

## Input Artifacts
specs/intents/{intent}/units/{unit}/architecture.md (required)
specs/intents/{intent}/units/{unit}/data-model.md
specs/intents/{intent}/units/{unit}/contracts/api-spec.json
story-{ID}.md (active story)
.specify/memory/standards/tech-stack.md

## Steps
1. Verify architecture.md exists — if missing: STOP, run sk.design first
2. [REFINE MODE] if plan.md exists, [CREATE MODE] if not
3. Write technical plan covering:
   - Technical approach and key decisions
   - Component breakdown (what to build, in what order)
   - Data layer changes (migrations, new entities referencing data-model.md)
   - API changes (new or modified endpoints referencing api-spec.json)
   - Test strategy (unit tests, integration tests, contract tests)
   - Dependencies on other services or units
   - Risks and open questions
   All decisions must reference architecture.md explicitly
4. Write plan to:
   specs/intents/{intent}/units/{unit}/stories/{story-id}/plan.md
5. If checkpoint_mode = confirm: pause after plan, wait for approval
   On approval: set story frontmatter checkpoint_status: approved

## Output Artifacts
specs/intents/{intent}/units/{unit}/stories/{story-id}/plan.md

## Quality Bar
- Explicit reference to architecture.md
- Tech stack decisions justified against tech-stack.md
- No contradictions with architecture.md
- Confirm checkpoint approved before tasks proceed
