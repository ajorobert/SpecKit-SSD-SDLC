# sk.session
Manages local development session.
Role: any

## Subcommands

### sk.session start [--role <role>]
1. Verify session.yaml role is null
   NOT null → report active session, suggest sk.session end first
2. Ask the user (via interactive chat or `ask_question` tool) the following configuration questions:
   - **Role** — which role for this session? (po, architect, lead, backend, frontend, backend-qa, frontend-qa, security)
   - **Base branch** — which branch to create the new one from? Present these options:
     1. Use the `dev` branch as the base branch **(default)**
     2. Use the current branch `{current_branch_name}` as the base branch
     3. Other — let the user specify a custom branch name
     - Resolve `{current_branch_name}` by reading the active git branch (`git branch --show-current`) before asking.
     - If the user makes no selection (or just confirms/skips), default to `dev`.
   - **Feature name** — what is the feature called? (used in the branch name)
   - **Story Id** — story identifier for branch tracking (e.g. story-001)
   - **Jira Id** — linked Jira ticket identifier (e.g. AUTH-102)
   - **Focus story** — any story ID to focus on initially? (optional — there are none yet, so you can skip)
3. Checkout the selected base branch: `git checkout {base_branch}`
4. Generate the branch name using the pattern: `feature/{story-id}-{jira-id}-{feature-name}-{YYYYMMDD}`
   - Sanitize `{story-id}`, `{jira-id}`, and `{feature-name}` first: lowercase each and replace any whitespace with hyphens (e.g. "auth login" → "auth-login")
   - Use today's date for `{YYYYMMDD}`
   - Example: story `story-001`, jira `AUTH-102`, feature `auth login`, date 2026-06-17 → `feature/story-001-auth-102-auth-login-20260617`
5. Create and checkout the new feature branch: `git checkout -b {generated_branch_name}`
6. Generate session_id: `{role}-{YYYYMMDD}` or "session-{YYYYMMDD}" if no role
7. If a focus story was selected:
   - Read story frontmatter from the specs directory
   - Determine active_story_id, active_unit_id, active_intent_id
   - Initialize stories_touched with `[active_story_id]` and units_touched with `[active_unit_id]`
8. Write session.yaml:
   - Set role, session_id, branch (set to `{generated_branch_name}`)
   - Set active_story_id, active_unit_id, active_intent_id (derived from the focus story if provided, else null)
   - Set stories_touched, units_touched (based on the focus story if provided, else `[]`)
9. Report: session started, feature branch, base branch, and active focus story
   If role set: list natural commands for that role
   If no role: note that Group B/C/D commands are available without a role; Group A (sk.implement, sk.test, sk.review, sk.investigate) require sk.session switch --role first


### sk.session restore
Use when session.yaml is missing but the working branch already exists.
1. Read current git branch name
2. Parse story-id, jira-id, feature-name, and date from branch name — format: feature/{story-id}-{jira-id}-{feature-name}-{YYYYMMDD}
   Cannot parse → ask user to provide role and session_id manually
3. Derive session_id: {role}-{YYYYMMDD} (ask user for role, since it is no longer encoded in the branch name)
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
