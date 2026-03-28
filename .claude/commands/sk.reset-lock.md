# sk.reset-lock
Clears stuck session lock.
Role: any

## Steps
1. Read .claude/session.lock — show contents to user
2. Confirm with user
3. Delete .claude/session.lock
4. Show current session.yaml
