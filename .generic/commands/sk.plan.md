<!-- GENERIC LAYER — self-contained command -->
<!-- Before executing: read .generic/hooks/pre-command.md -->
<!-- After executing: read .generic/hooks/post-command.md -->
<!-- Context to load: see .generic/context-maps/command-context-map.md -->

# sk.plan
Wraps: upstream.plan
Role: backend-lead | frontend-lead
Story-level command — requires active_story_id

## Pre-flight
1. Read session.yaml active_story_id
   NULL → STOP: run sk.session focus --story {id} first
2. Read story frontmatter from story-{ID}.md
3. Verify story status = ready
   NOT ready → warn user, ask to confirm proceed
4. Load skills in order:
   a. .claude/skills/domain-model/SKILL.md
   b. .claude/skills/service-registry/SKILL.md
   c. .claude/skills/architecture-decisions/SKILL.md
   d. .claude/skills/standards/SKILL.md (tech-stack.md only)
5. Read unit architecture.md if exists:
   specs/intents/{intent}/units/{unit}/architecture.md
   This is the architectural context for this plan

## Cross-service check
- Story touches existing contracts? → carry into plan
- Story introduces new domain entities? → flag for post-execution update
- Story conflicts with active ADR? → STOP, report conflict

## Checkpoint gate
Read story frontmatter checkpoint_mode:
- validate → verify architecture.md exists for active unit
  MISSING → STOP: run sk.architecture first
- confirm | autopilot → proceed

## Write plan
Write technical plan to:
specs/intents/{intent}/units/{unit}/stories/{story-id}/plan.md

Plan must cover:
- Technical approach and key decisions (reference architecture.md explicitly)
- Component breakdown (what to build, in what order)
- Data layer changes (migrations, new entities referencing data-model.md)
- API changes (new or modified endpoints referencing api-spec.json)
- Test strategy (unit tests, integration tests, contract tests)
- Dependencies on other services or units
- Risks and open questions

## Confirm checkpoint
If checkpoint_mode = confirm:
  STOP — present plan summary
  Wait for explicit approval
  On approval: set story frontmatter checkpoint_status: approved

## Post-execution
Update story frontmatter: status: ready (if was draft)
Suggest ADR if cross-service decision made