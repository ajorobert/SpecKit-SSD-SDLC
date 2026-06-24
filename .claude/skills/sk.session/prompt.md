# sk.session
Manages local development session.
Role: any

> **Path & branch conventions are canonical in `.specify/memory/standards/story-lifecycle.md`**
> (§3 path resolution, §5 branch convention). Load it before resolving any path.

## Session Rules (per story-lifecycle.md §5)
- **One session can support multiple roles** — switch roles via `sk.session switch --role`.
- **One feature branch represents one unit** (the feature boundary). The branch maps 1:1 to the
  active unit (`specs/intents/{intent}/units/{unit}/`).
- **Multiple projects can participate in the same unit** — design/plan/implement/test are
  project-scoped under the unit; the branch still represents the single unit.
- **A unit carries one or more stories** (one per layer: frontend/backend/mobile). The active
  unit is the session's working focus; `active_story_id` selects the focused layer story.

## Subcommands

### sk.session start [--role <role>]

1. **Pre-flight** — Verify session.yaml role is null.
   NOT null → report active session, suggest `sk.session end` first.

2. **Role**
   - If `--role <role>` is provided in the command (e.g. `/sk.session start --role backend`), use the specified role.
   - If no role is provided, ask the user to select one: **Product Owner | Architect | Lead | Backend Developer | Frontend Developer**.
   - Map the selection to the role key used internally: `po | architect | lead | backend | frontend`.

3. **Base branch** (default: `dev`)
   - Automatically detect the current git branch: `git branch --show-current` → `{current_branch_name}`.
   - Present these options:
     1. Use `dev` as the base branch **(default)** — branch from `dev` even if not currently on it.
     2. Use the current branch `{current_branch_name}` as the base branch (override).
     3. Other — let the user specify a custom branch name (override).
   - If the user skips the selection, default to `dev`.

4. **Active unit** (the session focus, per story-lifecycle.md §3)
   - Resolve from `session.yaml` `active_intent_id` + `active_unit_id` (→ `unit_dir`).
   - If none is set: ask the user to pick an existing unit (`sk.session list`), or instruct them
     to run `sk.intent` → `sk.unit` first to create one. The branch represents this unit.

5. **Checkout base + create feature branch** (per story-lifecycle.md §5)
   - `git checkout {base_branch}` (default `dev`).
   - Generate the branch name: `feature/{active_intent_id}/{unit}-{YYYYMMDD}`
     - Example: `feature/001-authentication/login-20260624`.
     - Keep `{active_intent_id}` and `{unit}` **verbatim**; append today's `{YYYYMMDD}`. The user
       may override with a custom branch name.
   - `git checkout -b {generated_branch_name}`

6. **session_id**: `{role}-{YYYYMMDD}` (or `session-{YYYYMMDD}` if no role).

7. **Active unit handling**
   - The active unit is the session focus by default; continue with it throughout the session.
   - If a unit change is required: allow the user to switch, updating `active_intent_id` /
     `active_unit_id` / `unit_dir` (and clearing `active_story_id` until a story is focused).

8. **Write session.yaml**: role, session_id, branch (`{generated_branch_name}`), base_branch,
   `active_intent_id`, `active_unit_id`, `unit_dir`, `active_story_id`, jira_id, projects_touched,
   roles_used, stories_touched, units_touched.

9. **Report**: session started, feature branch, base branch, role, and active focus unit.
    - If role set: list natural commands for that role.
    - If no role: note that Group B/C/D commands are available without a role; Group A (sk.implement, sk.test, sk.review, sk.investigate) require `sk.session switch --role` first.

### sk.session restore
Use when session.yaml is missing but the working branch already exists.
1. Read current git branch name
2. Parse the intent-id and unit from the branch name — format:
   `feature/{intent-id}/{unit}-{YYYYMMDD}` (per story-lifecycle.md §5).
   Cannot parse → ask the user to provide role, intent, and unit manually.
3. Derive session_id: {role}-{YYYYMMDD} (or session-{YYYYMMDD} if role unknown).
4. Write session.yaml with recovered values; resolve `unit_dir` from the parsed
   `specs/intents/{intent-id}/units/{unit}/` if it exists. Leave projects_touched/units_touched empty.
5. Remind the user to run `sk.session focus --unit {intent-id}/{unit}` to restore unit context.
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
5. Commit: "[{role(s) used or 'mixed'}] {session_id}: {active_intent_id}/{active_unit_id} across {projects_touched}"
   - If `projects_touched` is empty, derive it from the unit: list the subfolders under
     `UNIT_DIR/04-implementation/` (the projects actually implemented). Use "—" if none.
6. git push
7. If gh CLI available: open PR to the base branch (default `dev`)
8. Reset session.yaml all fields to null
9. Report: session ended, branch pushed

### sk.session focus --unit <intent-id>/<unit> | --story <id>
1. **--unit `{intent-id}/{unit}`** (the common case): resolve
   `UNIT_DIR = specs/intents/{intent-id}/units/{unit}/`. Set `active_intent_id`, `active_unit_id`,
   `unit_dir`; clear `active_story_id`.
2. **--story `{id}`**: within the active unit, set `active_story_id` to the matching
   `stories/story-{Layer}-...-{NNN}.md` (focus a single layer story).
3. Write session.yaml, report current focus.

### sk.session status
1. Read session.yaml
2. Read `unit_dir/unit-brief.md`; if `active_story_id` set, read the focused story file frontmatter.
3. Report:
   - Role(s) (if set), branch, base branch, session_id
   - Active: intent ({active_intent_id}), unit ({active_unit_id}), unit_dir, focused story, projects_touched
   - Story/unit status and checkpoint_mode
   - If role set: natural commands for that role
   - If role null: all self-asserting commands available; note Group A requires role

### sk.session list [--intent <id>] [--status <status>]
1. Glob `specs/intents/*/units/*/` for all units; read each `unit-brief.md` + its `stories/`.
2. Display table:
   | Intent | Unit | Stories | Status | Owner | Checkpoint | Branch |
3. Apply filters if provided.
