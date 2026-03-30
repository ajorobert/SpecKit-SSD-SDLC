# sk.session
Manages local development session.
Role: any

## Subcommands

### sk.session start [--role <role>]
1. Verify session.yaml role is null
   NOT null → report active session, suggest sk.session end first
2. Generate session_id: {role}-{YYYYMMDD} or "session-{YYYYMMDD}" if no role
3. Generate branch: {role}/session-{YYYYMMDD}
4. Run: git checkout -b {branch}
5. Write session.yaml: role, branch, session_id
6. Report: session started, branch, available commands for role

### sk.session switch --role <role>
1. Read current session.yaml — verify session active
2. Update role field
3. Report: role switched, available commands for new role

### sk.session end
1. Show session.yaml stories_touched and units_touched
2. Ask user to confirm complete
3. git add specs/ .specify/memory/ history/
4. Commit: "[{role}] {session_id}: worked on {units_touched}, {stories_touched}"
5. git push
6. If gh CLI available: open PR to dev branch
7. Reset session.yaml all fields to null
8. Report: session ended, branch pushed

### sk.session focus --unit <id> | --story <id>
1. If --unit: set active_unit_id, derive active_intent_id
   Set active_story_id: null
2. If --story: read story frontmatter
   Set active_story_id, active_unit_id, active_intent_id
3. Write session.yaml, report current focus

### sk.session status
1. Read session.yaml
2. If active_story_id: read story frontmatter
3. Report:
   - Role, branch, session_id
   - Active: intent, unit, story
   - Story status and checkpoint_mode
   - Natural commands for current role

### sk.session list [--intent <id>] [--status <status>]
1. Scan specs/intents/ for all story-*.md files
2. Read frontmatter from each
3. Display table:
   | ID | Title | Status | Owner | Checkpoint | Branch |
4. Apply filters if provided
