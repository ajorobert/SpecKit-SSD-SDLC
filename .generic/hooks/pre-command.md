# Pre-Command Hook
Executes before every sk.* command.

## Trigger
event: before_tool_use
matcher: sk.*

## Steps

1. CHECK LOCK
   - Read .claude/session.lock
   - EXISTS: read contents, report to user
     Display: "Run sk.reset-lock if no other session is active"
     HALT
   - NOT EXISTS: continue

2. ACQUIRE LOCK
   - Write .claude/session.lock:
     command: <sk.* command name>
     started_at: <ISO 8601 timestamp>
   - If write fails: HALT, report to user

3. VALIDATE SESSION
   - Read .claude/session.yaml
   - If role is null: HALT
     Display: "No active session. Run sk.session start --role <role>"
   - Store session context in working memory
