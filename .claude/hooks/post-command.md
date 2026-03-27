# Post-Command Hook
Executes after every sk.* command automatically.

## Trigger
event: after_tool_use
matcher: sk.*

## Steps (execute in order, no skipping)

1. UPDATE STATE
   Read .specify/state.yaml
   Write these fields:
   - last_command: <name of sk.* command that just ran>
   - last_command_at: <ISO 8601 timestamp>
   - last_command_status: success | failed | interrupted
   - last_modified_by: "<command-name> @ <timestamp>"
   Re-read state.yaml and verify written values are present
   If verification fails: report to user, do not release lock

2. MEMORY UPDATES (conditional)
   Execute only the updates relevant to the command that just ran:

   If last_command = sk.plan OR sk.architecture:
   - Check if new services were introduced → update service-registry.md
   - Check if new domain entities introduced → update domain-model.md

   If last_command = sk.datamodel:
   - Update domain-model.md with new or modified entities

   If last_command = sk.contracts:
   - Update service-registry.md with new or modified contracts

   If last_command = sk.adr:
   - Update architecture-decisions.md index table

3. ADR TRIGGER (conditional)
   If last_command = sk.plan OR sk.architecture:
   - Evaluate: did this command produce a cross-service decision?
   - Evaluate: were real alternatives considered?
   - Evaluate: does this involve auth, payments, or security?
   If any YES: surface ADR suggestion to user, wait for confirmation
   Do not create ADR without explicit user confirmation

4. PHR TRIGGER (conditional)
   If last_command = sk.architecture:
   - Automatically create PHR via sk.phr
   If last_command = sk.implement:
   - Evaluate: were novel tradeoffs resolved during implementation?
   - If YES: automatically create PHR via sk.phr

5. RELEASE LOCK
   Delete .specify/state.lock
   Confirm deletion
   If deletion fails: report to user
   Do not leave lock file on clean exit under any circumstances
