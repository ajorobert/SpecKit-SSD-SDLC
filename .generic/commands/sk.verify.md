# sk.verify
Story-level command. PASS/FAIL quality gate.
Reads quality-gates.md and audits all artifacts for active story.

## Pre-flight
1. Read session.yaml active_story_id
   NULL → STOP: run sk.session focus --story {id} first
2. Read story frontmatter from story-{ID}.md
3. Load skills:
   a. .claude/skills/governance/SKILL.md (quality-gates.md)
   b. .claude/skills/architecture-decisions/SKILL.md
   c. .claude/skills/standards/SKILL.md (all files)

## Gate evaluation

Evaluate only gates relevant to story current status:

### Spec Gate (always evaluate)
Artifacts checked:
- specs/intents/{intent}/intent.md → exists and objective populated?
- specs/intents/{intent}/units/{unit}/unit-brief.md → exists?
- story-{ID}.md → acceptance criteria populated?
- story-{ID}.md → no undefined external dependencies?

### Architecture Gate (if architecture.md exists for unit)
Artifacts checked:
- architecture.md → exists and status != draft?
- architecture.md → stories-covered includes active story?
- service-registry.md → new services registered?
- domain-model.md → new entities added?
- architecture-decisions.md → ADR exists for cross-service decisions?
- story frontmatter → checkpoint_mode set?

### Plan Gate (if plan.md exists for story)
Artifacts checked:
- plan.md → exists and populated?
- contracts/api-spec.json → exists if new endpoints planned?
- data-model.md → exists if new entities in plan?
- service-registry.md → no contract conflicts?
- story frontmatter → checkpoint approved if confirm|validate mode?

### Implementation Gate (if tasks.md exists and all tasks complete)
Artifacts checked:
- tasks.md → all tasks marked [X]?
- PHR → exists in history/prompts/ for this story?
- coding-standards.md → no known violations flagged during implement?
- story frontmatter → status = review?

## Output format

## Verification Report: {story-id}
Date: {date}
Story: {title}
Status: {current status}

### Spec Gate:             PASS | FAIL | SKIP
### Architecture Gate:     PASS | FAIL | SKIP
### Plan Gate:             PASS | FAIL | SKIP
### Implementation Gate:   PASS | FAIL | SKIP

### Overall: PASS | FAIL

### Failures
| Gate | Check | Finding |
|------|-------|---------|

### Recommendations


## Post-execution
Overall PASS → post-command hook sets story status: done
Overall FAIL → story status unchanged, user must resolve failures
Report is informational only — do not auto-fix failures
