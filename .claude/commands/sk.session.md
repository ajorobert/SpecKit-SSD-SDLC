# sk.session
Manages local development session state.
Does not acquire the command lock — it IS the session manager.

## Subcommands

### sk.session start --role <role> [--intent <id>]
Roles: po | architect | backend-lead | frontend-lead | engineer

1. Verify .claude/session.yaml role is null
   - NOT null: report active session exists, suggest sk.session end first
2. Generate session_id: {role}-{YYYYMMDD}
3. Generate branch name: {role}/session-{YYYYMMDD}
4. Create git branch: git checkout -b {branch}
5. Write session.yaml:
   - role, session_id, branch, started, active_intent_id (if --intent provided)

## Agent spawning
Map role to agent definition:
po               → .claude/agents/po.md
architect        → .claude/agents/architect.md
lead             → .claude/agents/lead.md
backend-engineer → .claude/agents/backend-engineer.md
frontend-engineer→ .claude/agents/frontend-engineer.md

Load the mapped agent definition into session context.
Inform user which agent persona is now active.
Display the agent's allowed commands as a reminder.

6. Report: session started, branch created, role active

### sk.session end
1. Read session.yaml — show stories_touched and units_touched
2. Ask user to confirm session is complete
3. Stage all changes: git add specs/ .specify/memory/
4. Generate commit message:
   [{role}] session {session_id}: {units_touched} units, {stories_touched} stories
5. Commit and push branch
6. If gh CLI available: open PR to dev branch automatically
7. Clear session.yaml: reset all fields to null
8. Report: session ended, branch pushed, PR opened (if applicable)

### sk.session focus --unit <unit-id> | --story <story-id>
1. Read session.yaml
2. If --unit:
   - Verify unit exists in specs/intents/
   - Set active_unit_id, derive active_intent_id from unit ID prefix
   - Set active_story_id: null (unit focus clears story focus)
3. If --story:
   - Verify story file exists in specs/intents/
   - Read story frontmatter
   - Set active_story_id, active_unit_id, active_intent_id from story ID
4. Write updated session.yaml
5. Report: current focus summary

### sk.session status
1. Read session.yaml
2. Read active story frontmatter if active_story_id set
3. Report:
   - Role, session_id, branch
   - Current focus: intent, unit, story
   - Stories touched this session with their current status
   - Last command run

### sk.session list [--intent <id>] [--status <status>]
1. Scan specs/intents/ recursively for all story-*.md files
2. Read frontmatter from each story file
3. Display as table:
   | ID | Title | Status | Owner | Checkpoint | Branch |
4. Filter by --intent or --status if provided
5. This is the team kanban view — shows all work across all intents
