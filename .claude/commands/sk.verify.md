# sk.verify
PASS/FAIL quality gate for active story.
Role: architect, lead | Level: story

**When to run:** After sk.test passes (test-status = pass in story frontmatter), before sk.ship.
This is the final gate — not a mid-implementation check. Run sk.analyze if you need a
consistency check earlier in the cycle (after implement, before test).

## Input Artifacts
story-{ID}.md (active story + frontmatter)
All unit artifacts (architecture.md, data-model.md, contracts/)
All story artifacts (plan.md, tasks.md)
.specify/memory/architecture-decisions.md
.specify/memory/standards/ (all files)
.claude/skills/governance/SKILL.md (quality-gates.md)

## Steps
1. Read quality-gates.md — evaluate all applicable gates
2. Spec Gate: always evaluate
3. Architecture Gate: evaluate if architecture.md exists
4. Plan Gate: evaluate if plan.md exists
5. Implementation Gate: evaluate if tasks.md complete
6. Output structured report with PASS/FAIL per gate
7. Overall PASS → story status set to done via post-command hook
   Overall FAIL → story status unchanged, list failures

## Output Artifacts
Verification report (displayed, not written to file)
story-{ID}.md status updated if overall PASS

## Quality Bar
- Every gate item explicitly PASS, FAIL, or SKIP with reason
- FAIL items include specific finding not generic message
- Recommendations actionable not vague
