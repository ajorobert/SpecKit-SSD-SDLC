# sk.phr
No skill load required.

## Pre-flight
1. Read session.yaml for context

## Steps
1. Collect:
   - Related command
   - Prompt or decision being recorded
   - Context at time of decision
   - Outcome and rationale
   - Alternatives rejected

2. Determine feature name from session active_unit_id or active_story_id

3. Run .your-layer/scripts/create-phr.sh "<feature-name>"

4. Write PHR using .your-layer/templates/phr-template.md
   Include story ID and unit ID from session context
