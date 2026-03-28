# sk.impact
Intent-level command. Run before starting any new intent or unit.
Assesses blast radius of proposed work on the existing system.

## Pre-flight
1. Read session.yaml — verify session active
2. Load skills in order:
   a. .claude/skills/system-context/SKILL.md
   b. .claude/skills/service-registry/SKILL.md
   c. .claude/skills/domain-model/SKILL.md

## Steps

### A. Collect proposed work description
Ask user:
- What is the intent or unit being proposed?
- Which services are expected to be involved?
- Any known external dependencies?

### B. Impact analysis
Evaluate against loaded context:

Service impact:
- Which existing services does this touch?
- Does this require contract changes on existing services?
- Does this introduce a new service?

Domain impact:
- Does this introduce new domain entities?
- Does this conflict with existing bounded contexts?
- Does this require changes to shared kernel?

Cross-cutting impact:
- Does this affect auth, payments, or security patterns?
- Does this affect more than one frontend surface?
- Does this require a new external dependency?

### C. Risk classification
Classify overall impact:
- LOW: isolated to one service, no contract changes, no new entities
- MEDIUM: touches existing contracts OR introduces new entities
- HIGH: new service, breaking contract changes, or cross-cutting concern

### D. Output impact report
Format:

## Impact Report: {proposed work}
Date: {date}
Risk: LOW | MEDIUM | HIGH

### Affected Services
### Domain Changes
### Contract Changes Required
### Recommended Checkpoint Mode
### ADR Required: YES | NO
### Recommended Next Step


### E. Save report
Count existing impact files for today:
COUNT=$(ls specs/intents/{active_intent_id}/impact-{date}-*.md
        2>/dev/null | wc -l)
SEQUENCE=$(printf "%02d" $((COUNT + 1)))

Write report to:
- Active intent set: specs/intents/{active_intent_id}/impact-{date}-{SEQUENCE}.md
- No active intent:  specs/impact-{date}-{SEQUENCE}.md

## Post-execution
If ADR Required = YES: surface ADR suggestion to user
