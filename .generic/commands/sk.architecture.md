# sk.architecture
Unit-level command. ONE architecture document per unit.
Covers all stories within the unit.

## Pre-flight
1. Read session.yaml active_unit_id
   NULL → STOP: run sk.session focus --unit {id} first
2. Load skills in order:
   a. .claude/skills/system-context/SKILL.md
   b. .claude/skills/domain-model/SKILL.md
   c. .claude/skills/service-registry/SKILL.md
   d. .claude/skills/architecture-decisions/SKILL.md
   e. .claude/skills/standards/SKILL.md (tech-stack.md only)
3. Check if architecture.md exists for active unit:
   specs/intents/{intent}/units/{unit}/architecture.md
   EXISTS → [REFINE MODE]
   MISSING → [CREATE MODE]

## Cross-service check
Before designing:
- List all services in service-registry.md this unit interacts with
- Identify existing contracts that must be respected
- Identify ADRs that constrain this design
Report findings to user before proceeding

## Steps

### A. Service design
Define for this unit:
- Service name and responsibility
- Bounded context ownership
- Communication patterns (sync REST, async events, etc.)
- Dependencies on other services
- What this service exposes

### B. Internal structure
Define:
- Key components and their responsibilities
- Data flow within the unit
- Error handling strategy
- Authentication approach (reference ADR if exists)

### C. Stories coverage
List all stories in this unit and confirm architecture covers them:
Scan specs/intents/{intent}/units/{unit}/stories/
For each story: confirm architectural approach addresses it

### D. Write architecture document
Target: specs/intents/{intent}/units/{unit}/architecture.md

If [REFINE MODE]:
  1. Read existing architecture.md fully
  2. Identify what has changed based on current session context
  3. Preserve all existing content that remains valid
  4. Update only sections affected by changes
  5. Append to bottom of document:
     ---
     Revised: {date}
     Session: {session_id}
     Changes: {brief description of what changed and why}
     ---

If [CREATE MODE]:
  Write fresh document using this structure:

  ---
  unit: {unit-id}
  intent: {intent-id}
  status: draft | approved
  stories-covered: [{story-ids}]
  created: {date}
  updated: {date}
  ---

  # Architecture: {unit-name}

  ## Service Responsibility
  ## Bounded Context
  ## Communication Patterns
  ## Internal Components
  ## Data Flow
  ## External Dependencies
  ## Security Approach
  ## Error Handling
  ## Stories Coverage
  ## Open Questions

## Validate checkpoint
If session.yaml role = architect AND any story in unit has
checkpoint_mode = validate:
  PAUSE after writing document
  Instruct user: architecture requires approval before sk.plan can proceed
  User approves → update story frontmatter checkpoint_status: approved

## Post-execution
PHR created automatically by post-command hook
Suggest ADR for any significant design decision made
