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
1. Verify architecture.md exists — if missing: STOP, run sk.architecture first
2. [REFINE MODE] if plan.md exists, [CREATE MODE] if not
3. Execute upstream.plan from upstream-adapter.md with loaded context
4. Write plan referencing architecture.md explicitly
5. If checkpoint_mode = confirm: pause after plan, wait for approval
   On approval: set story frontmatter checkpoint_status: approved

## Output Artifacts
specs/intents/{intent}/units/{unit}/stories/{story-id}/plan.md

## Quality Bar
- Explicit reference to architecture.md
- Tech stack decisions justified against tech-stack.md
- No contradictions with architecture.md
- Confirm checkpoint approved before tasks proceed
