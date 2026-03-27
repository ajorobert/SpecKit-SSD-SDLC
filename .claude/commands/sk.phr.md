sk.phr
No skill load required.

Pre-flight
- Acquire lock per command-rules.md

Steps

1. Collect:
   - Related command that produced this record
   - Prompt or decision being recorded
   - Context at time of decision
   - Outcome and rationale
   - Alternatives that were rejected

2. Run .your-layer/scripts/create-phr.sh "<feature-name>"
3. Write the PHR using .your-layer/templates/phr-template.md
   into the file created by the script
4. Update state.yaml: last_command, last_command_at, last_command_status
5. Release lock
