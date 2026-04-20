# sk.story — Unified Story Capture Orchestrator
Runs the complete story capture and clarification pipeline.
Role: po (orchestrator) | Level: story

This skill orchestrates `sk.specify`, `sk.clarify`, and `sk.architect-probe` in sequence, running completeness checks and looping clarification as needed for both business and technical aspects.

## Mode Detection
Evaluate in this order:
**TARGETED**
- `sk.story --specify` → run Phase 1 only (standalone intent/unit/story capture)
- `sk.story --clarify` → run Phase 3 only (standalone business ambiguity resolution)
- `sk.story --probe` → run Phase 5 only (standalone technical constraints resolution)

**FULL PIPELINE**
- `sk.story` (no flag) → [FEATURE MODE]
- `sk.story --bug` → [BUG MODE]

## Pre-flight
1. Read `session.yaml`
2. Load `.specify/memory/system-context.md`, `.specify/memory/architecture-decisions.md`, `.specify/memory/domain-model.md`

## Orchestration

### Phase 1 — Story Capture
Invoke sub-skill: `sk.story/sk.specify` (or `--bug` if in bug mode)
- Wait for specify phase to complete and write `story-{ID}.md`
- Read back `active_story_id` from `session.yaml`

### Phase 2 — Business Completeness Assessment
Run a structural coverage check on the generated `story-{ID}.md`.
Score each item below as ✅ Clear, ⚠️ Partial, or ❌ Missing.

**Business Checklist:**
- Story Structure
  - [ ] User story follows "As a / I want / So that" format
  - [ ] Actor is a specific role, not generic ("user")
  - [ ] Action is a concrete verb, not abstract ("manage")
  - [ ] Value connects to a business outcome
- Acceptance Criteria
  - [ ] Minimum 3 criteria present
  - [ ] At least 1 negative/error scenario covered
  - [ ] All criteria are testable (GWT or condition-based)
  - [ ] No vague qualifiers without metrics
- Scope
  - [ ] Out-of-scope section is populated (not empty)
  - [ ] No implicit scope assumptions

Gather all items marked ⚠️ Partial or ❌ Missing as seeds for Phase 3.
If all items are ✅ Clear, skip Phase 3 and go to Phase 4.

### Phase 3 — Iterative Business Clarification
Loop `sk.story/sk.clarify` up to 3 times to resolve the gaps identified in Phase 2.

**Round 1:**
- Present the ⚠️/❌ items to the clarify sub-skill.
- Clarify phase asks up to 5 questions.
- Integrate user answers into `story-{ID}.md`.
- Re-run Phase 2 Assessment. If all ✅, exit loop.
- **Round 2 & 3:** Repeat, adjusting questions to remaining gaps. Exit loop after Round 3 regardless.

### Phase 4 — Technical Completeness Assessment
Run an engineering readiness check on `story-{ID}.md`.
Score each item below as ✅ Clear, ⚠️ Partial, or ❌ Missing.

**Technical Checklist:**
- Integration & Data
  - [ ] Entities involved are identified and data inputs/outputs are concrete.
  - [ ] External dependencies and downstream failure modes addressed.
- NFRs & Scale
  - [ ] Performance targets, request volume, or scale expectations defined.
- Security boundaries
  - [ ] Tenant isolation or explicitly restricted actors defined.
- Observability
  - [ ] Business value telemetry/tracking metrics defined.
- UX & Design Constraints
  - [ ] Design references (Figma/assets) documented if frontend.

Gather all items marked ⚠️ Partial or ❌ Missing as seeds for Phase 5.
If all items are ✅ Clear, skip Phase 5 and go to Phase 6.

### Phase 5 — Iterative Technical Clarification
Loop `sk.story/sk.architect-probe` up to 2 times to resolve gaps from Phase 4.

**Round 1:**
- Present the ⚠️/❌ items to the architect-probe sub-skill.
- Probe phase asks up to 3 questions translating technical needs to business context.
- Integrate user answers into `story-{ID}.md`.
- Re-run Phase 4 Assessment. If all ✅, exit loop.
- **Round 2:** Repeat if needed. Exit loop after Round 2 regardless.

### Phase 6 — Final Validation Gate
Before marking the story as ready:
1. Show a combined summary of the final Business & Technical Assessments.
2. If all items are ✅ across both:
   - Auto-set `status: ready` in the story frontmatter.
   - Display success summary.
3. If any ❌ remain:
   - Display the missing items.
   - Ask PO: "Type 'proceed' to accept and proceed (items will be flagged as risk), or 'clarify' to do one more manual round."
   - If 'proceed': set `status: ready`.

## Completion Report
```
sk.story complete.
Story: {story-id} — {story title}
Status: ready

Checklist Summary:
- Business Passed: {X}/{Total}
- Technical Passed: {Y}/{Total}
- Missing: {Z} (listed if any)

Next step: /sk.design (or /sk.ff if continuing the pipeline)
```
