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
5. Write session.yaml: role (null if not provided), branch, session_id
6. Report: session started, branch
   If role set: list natural commands for that role
   If no role: note that Group B/C/D commands are available without a role; Group A (sk.implement, sk.test, sk.review, sk.investigate) require sk.session switch --role first

### sk.session restore
Use when session.yaml is missing but the working branch already exists.
1. Read current git branch name
2. Parse role and date from branch name — format: {role}/session-{YYYYMMDD}
   Cannot parse → ask user to provide role and session_id manually
3. Derive session_id: {role}-{YYYYMMDD}
4. Write session.yaml with recovered values (active_intent_id, active_unit_id, active_story_id, stories_touched, units_touched all null/[])
5. Remind user to run sk.session focus to restore active story context
6. Report: session restored on branch {branch}

### sk.session switch --role <role>
1. Read current session.yaml — verify session active
2. Update role field
3. Report: role switched, available commands for new role

### sk.session end
1. Show session.yaml stories_touched and units_touched
2. Ask user to confirm complete
3. git add specs/ .specify/memory/ history/
4. Commit: "[{role or 'mixed'}] {session_id}: worked on {units_touched}, {stories_touched}"
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
   - Role (if set), branch, session_id
   - Active: intent, unit, story
   - Story status and checkpoint_mode
   - If role set: natural commands for that role
   - If role null: all self-asserting commands available; note Group A requires role

### sk.session list [--intent <id>] [--status <status>]
1. Scan specs/intents/ for all story-*.md files
2. Read frontmatter from each
3. Display table:
   | ID | Title | Status | Owner | Checkpoint | Branch |
4. Apply filters if provided
