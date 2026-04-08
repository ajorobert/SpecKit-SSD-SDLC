# sk.specify
Captures intent, decomposes to units and stories.
Role: po | Level: intent → unit → story

## Mode Detection
- `sk.specify --bug` → [BUG MODE] bug report interview framing
- `sk.specify` (no flag) → [FEATURE MODE] user story interview framing
Declare mode at start of execution.

## Input Artifacts
.specify/memory/system-context.md
session.yaml (active_intent_id, active_unit_id)

## Steps

### Step 1 — Resolve Intent
Read active_intent_id from session.yaml.
NULL → ask user for intent title and code (e.g. CHK)
Create specs/intents/{NNN}-{name}/intent.md if new.

### Step 2 — Resolve Unit
Read active_unit_id from session.yaml.
NULL → ask user for unit title and code (e.g. PAY)
Create specs/intents/{intent}/units/{unit}/unit-brief.md if new.

### Step 3 — [FEATURE MODE only] Pre-validation (optional)
If creating a new intent (active_intent_id was NULL before step 1):
  Ask: "Would you like to validate this idea against existing intents and constraints first? (y/n)"
  If yes:
    - Load .specify/memory/system-context.md and list existing intents from specs/intents/
    - Load .specify/memory/architecture-decisions.md and .specify/memory/domain-model.md
    - Evaluate: does this idea duplicate an existing intent? does it conflict with any ADR?
    - Report findings. If major concerns: suggest resolving before proceeding.
    - If no concerns: confirm "No conflicts found. Proceeding to story capture."

### Step 4 — Capture Story

#### [FEATURE MODE]
- Ask: who is the user, what do they need, why (business value)
- Ask: what are the acceptance criteria (minimum 3, verifiable, user-focused)
- Ask: what is explicitly out of scope

#### [BUG MODE]
- Ask: what is the expected behavior? (reference the relevant spec, story ID, or acceptance criterion if known)
- Ask: what is the actual/broken behavior? (be specific — what happens instead)
- Ask: steps to reproduce (numbered list)
- Ask: affected unit and story ID if known (set as `related_story` in frontmatter)
- Ask: acceptance criteria for the fix — when is this considered resolved? (minimum 2)
- Note: out of scope defaults to "no new features introduced by this fix"

### Step 5 — Write Story
Write story to:
  specs/intents/{intent}/units/{unit}/stories/story-{ID}.md
  using story-template.md, ID format: {INTENT}-{UNIT}-{NNN}

In [BUG MODE]: set `story_type: bug` in frontmatter and populate:
  - `expected_behavior`
  - `actual_behavior`
  - `reproduction_steps`
  - `related_story` (if provided)

### Step 6 — Classify Checkpoint
Read governance skill → set checkpoint_mode in story frontmatter.
Bug stories default to checkpoint_mode: standard unless the fix touches
a service boundary or data model (→ confirm).

## Output Artifacts
specs/intents/{intent}/intent.md (if new)
specs/intents/{intent}/units/{unit}/unit-brief.md (if new)
specs/intents/{intent}/units/{unit}/stories/story-{ID}.md

## Quality Bar

### Feature mode
- Story has clear user story format
- Minimum 3 acceptance criteria
- checkpoint_mode set in frontmatter
- Out of scope items listed

### Bug mode
- Expected vs actual behavior clearly distinguished
- Reproduction steps are numbered and specific
- Minimum 2 acceptance criteria (definition of fixed)
- story_type: bug in frontmatter
- checkpoint_mode set (default: standard)
