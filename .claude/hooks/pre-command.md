# Pre-Command Hook
Executes before every sk.* command automatically.

## Trigger
event: before_tool_use
matcher: sk.*

## Steps (execute in order, no skipping)

1. CHECK LOCK
   - Read .specify/state.lock
   - If file exists:
     - Read and display contents to user
     - Display: "A lock file exists. No sk.* command can run until resolved."
     - Display: "If no other session is active, run sk.reset-lock"
     - HALT — do not proceed
   - If file does not exist: continue

2. ACQUIRE LOCK
   - Write .specify/state.lock:
     command: <name of sk.* command being invoked>
     started_at: <ISO 8601 timestamp>
   - Confirm file written before continuing
   - If write fails: HALT, report to user

3. READ STATE
   - Read .specify/state.yaml
   - If file missing or invalid YAML: HALT, report to user
   - Store current state in working memory for this session
