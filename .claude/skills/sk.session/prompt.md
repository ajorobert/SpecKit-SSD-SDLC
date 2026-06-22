# sk.session
Manages local development session.
Role: any

## Subcommands

### sk.session start [--role <role>]

1. **Pre-flight** — Verify session.yaml role is null.
   NOT null → report active session, suggest `sk.session end` first.

2. **Role**
   - If `--role <role>` is provided in the command (e.g. `/sk.session start --role backend`), use the specified role.
   - If no role is provided, ask the user to select one: **Product Owner | Architect | Lead | Backend Developer | Frontend Developer**.
   - Map the selection to the role key used internally: `po | architect | lead | backend | frontend`.

3. **Base branch**
   - Automatically detect the current git branch: `git branch --show-current` → `{current_branch_name}`.
   - Present these options:
     1. If the current branch is `dev`, use `dev` as the base branch **(default)**.
     2. Use the current branch `{current_branch_name}` as the base branch.
     3. Other — let the user specify a custom branch name.
   - If the user skips the selection, default to `dev`.

4. **Feature name** (auto-generated — do NOT ask the user unless it cannot be determined)
   - Determine the feature name by this priority:
     1. Use the **Jira issue title** if a Jira ticket is linked.
     2. Otherwise, use the **active story title**.
   - Ask the user only if the feature name cannot be determined automatically by either source.
   - Convert to a branch-friendly format: lowercase, replace whitespace with hyphens (e.g. "Login page" → "login-page").

5. **Story Id** (auto-generated)
   - Scan all existing story files under `specs/intents/**/stories/`.
   - Identify the highest existing story number, then increment it to create the next story ID.

6. **Checkout base + create feature branch**
   - `git checkout {base_branch}`
   - Generate the branch name: `feature/{story-id}-{jira-id}-{feature-name}-{YYYYMMDD}`
     - Sanitize each segment: lowercase, replace whitespace with hyphens. Use today's date for `{YYYYMMDD}`.
   - `git checkout -b {generated_branch_name}`

7. **session_id**: `{role}-{YYYYMMDD}` (or `session-{YYYYMMDD}` if no role).

8. **Active story handling**
   - The current active story is the session focus by default. Do NOT request additional story input from the user — continue with the existing focused story throughout the session.
   - If a story change is required: allow the user to explicitly switch or provide a different story, and update the session focus (`active_story_id`, and the derived `active_unit_id` / `active_intent_id`) to the newly selected story.

9. **Write session.yaml**: role, session_id, branch (`{generated_branch_name}`), story_id, jira_id, active_intent_id, active_unit_id, active_story_id, stories_touched, units_touched.

10. **Report**: session started, feature branch, base branch, role, and active focus story.
    - If role set: list natural commands for that role.
    - If no role: note that Group B/C/D commands are available without a role; Group A (sk.implement, sk.test, sk.review, sk.investigate) require `sk.session switch --role` first.

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

> **Safety principle:** NEVER automatically stash or discard user changes without confirmation.
> Always ask the user before taking any action that could affect unfinished or uncommitted work.

1. Show session.yaml stories_touched and units_touched.
2. Ask user to confirm complete.
3. **Uncommitted-changes guard** — before committing or any branch switch, check the working tree:
   `git status --porcelain`.
   - **No pending changes** → continue with the end process.
   - **Pending changes detected** → PAUSE the workflow and ask the user how they want to proceed:
     - **Commit changes** — stage and commit the current work as part of ending the session (steps 4–5).
     - **Stash changes and continue** — `git stash` the current changes, then proceed.
     - **Cancel session end** — stop the workflow without committing, stashing, or changing the current branch.
   - NEVER stash or discard without explicit confirmation.
4. git add specs/ .specify/memory/ history/
5. Commit: "[{role or 'mixed'}] {session_id}: worked on {units_touched}, {stories_touched}"
6. git push
7. If gh CLI available: open PR to dev branch
8. Reset session.yaml all fields to null
9. Report: session ended, branch pushed

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
