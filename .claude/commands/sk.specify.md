# sk.specify
Wraps: upstream.specify

## Pre-flight
1. Acquire lock per command-rules.md
2. Load skill: .claude/skills/system-context/SKILL.md
3. Verify system-context.md and standards/tech-stack.md are populated
   - Either empty → STOP, inform user to run sk.constitution first

## Steps

### A. Intent resolution
Check state.yaml active_intent:
- NULL → this is a new intent
  1. Ask user for intent title
  2. Generate next intent number from .specify/intents/ directory
  3. Create .specify/intents/{NNN}-{intent-name}/intent.md:

     # Intent: {title}
     Status: active
     Created: {date}
     ## Objective
     ## Success Criteria
     ## Out of Scope

  4. Set state.yaml active_intent: {NNN}-{intent-name}

- NOT NULL → adding to existing intent, confirm with user

### B. Unit resolution
Check state.yaml active_unit:
- NULL → ask user which unit this story belongs to
  1. If unit is new: create .specify/intents/{intent}/units/{unit-name}/unit-brief.md:

     # Unit: {name}
     Bounded Context:
     Owns:
     Dependencies:
     Status: active

  2. Set state.yaml active_unit: {unit-name}

- NOT NULL → confirm with user or allow change

### C. Execute upstream specify
Read upstream.specify from upstream-adapter.md
Execute upstream specify instructions
Output goes to .specify/intents/{intent}/units/{unit}/stories/story-{NNN}.md
instead of upstream default location

### D. Checkpoint classification
Load skill: .claude/skills/governance/SKILL.md
Read checkpoint-rules.md
Evaluate current story against classification criteria
Set state.yaml checkpoint_mode: autopilot | confirm | validate
Report classification to user with reasoning

## Post-execution
1. Update state.yaml:
   - active_story: story-{NNN}
   - last_command: sk.specify
   - last_command_at: <timestamp>
   - last_command_status: success
2. Report: intent, unit, story, checkpoint_mode
3. Release lock
