# sk.session
Manages local development session.
Role: any

> **Path & branch conventions are canonical in `.specify/memory/standards/story-lifecycle.md`**
> (§3 story-id resolution, §5 branch convention). Load it before resolving any story path.

## Session Rules (per story-lifecycle.md §5)
- **One session can support multiple roles** — switch roles within a session via
  `sk.session switch --role`. The session is not pinned to a single role.
- **One feature branch represents one independent story.** The branch maps 1:1 to the story.
- **Multiple projects can participate in the same story** — planning/implementation/testing are
  project-scoped under the one story folder; the branch still represents the single story.
- The active story is always the session's working focus.

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

4. **Feature name** (auto-generated — do NOT ask the user unless it cannot be determined)
   - Determine the feature name by this priority:
     1. Use the **Jira issue title** if a Jira ticket is linked.
     2. Otherwise, use the **active story title**.
   - Ask the user only if the feature name cannot be determined automatically by either source.
   - Convert to a branch-friendly format: lowercase, replace whitespace with hyphens (e.g. "Login page" → "login-page").

5. **Story Id** (auto-generated, per story-lifecycle.md §3)
   - Glob `specs/STORY-*/` and the legacy `specs/intents/**/story-*.md`. Parse the numeric
     segment, take `max + 1`, zero-pad to 3 → `{ID}` (e.g. `001`). If none exist, start at `001`.
   - `active_story_id = "STORY-" + {ID}` (e.g. `STORY-001`) — the prefix appears exactly once.
   - If continuing an existing story, reuse its `active_story_id` instead of minting a new one.

6. **Checkout base + create feature branch** (per story-lifecycle.md §5)
   - `git checkout {base_branch}` (default `dev`).
   - Generate the branch name: `feature/{active_story_id}/{feature-name}-{YYYYMMDD}`
     - Example: `feature/STORY-001/customer-login-20260624`.
     - Keep `{active_story_id}` **verbatim** (preserve the `STORY-NNN` casing). Sanitize only the
       `{feature-name}` segment: lowercase, whitespace/punctuation → hyphens. Use today's date for
       `{YYYYMMDD}`. The user may override the generated name (custom branch name).
   - `git checkout -b {generated_branch_name}`

7. **session_id**: `{role}-{YYYYMMDD}` (or `session-{YYYYMMDD}` if no role).

8. **Story folder + active story handling**
   - Resolve `STORY_DIR = specs/{active_story_id}-{feature-name}/` (e.g.
     `specs/STORY-001-customer-login/`) — `active_story_id` already includes `STORY-`, do NOT
     prepend another. Created on first story-capture by sk.story; sk.session records the id/path.
   - The current active story is the session focus by default. Do NOT request additional story
     input — continue with the focused story throughout the session.
   - If a story change is required: allow the user to switch, and update `active_story_id` /
     `story_dir` to the newly selected story.

9. **Write session.yaml**: role, session_id, branch (`{generated_branch_name}`), base_branch,
   story_id, `active_story_id`, `story_dir`, jira_id, projects_touched, roles_used, stories_touched.
   (Legacy fields `active_intent_id` / `active_unit_id` / `units_touched` may be retained as null
   for backward compatibility with un-migrated tooling.)

10. **Report**: session started, feature branch, base branch, role, and active focus story.
    - If role set: list natural commands for that role.
    - If no role: note that Group B/C/D commands are available without a role; Group A (sk.implement, sk.test, sk.review, sk.investigate) require `sk.session switch --role` first.

### sk.session restore
Use when session.yaml is missing but the working branch already exists.
1. Read current git branch name
2. Parse the story id and date from the branch name — format:
   `feature/{story-id}/{feature-name}-{YYYYMMDD}` (per story-lifecycle.md §5).
   Cannot parse → ask the user to provide role and story id manually.
3. Derive session_id: {role}-{YYYYMMDD} (or session-{YYYYMMDD} if role unknown).
4. Write session.yaml with recovered values; resolve `story_dir` from the parsed story id if a
   `specs/STORY-{id}-*/` folder exists. Leave projects_touched/stories_touched empty.
5. Remind the user to run `sk.session focus --story {id}` to restore active story context.
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
5. Commit: "[{role(s) used or 'mixed'}] {session_id}: {story_id} across {projects_touched}"
   - If `projects_touched` is empty, derive it from the story folder: list the subfolders under
     `STORY_DIR/04-implementation/` (the projects actually implemented). Use "—" if none.
6. git push
7. If gh CLI available: open PR to the base branch (default `dev`)
8. Reset session.yaml all fields to null
9. Report: session ended, branch pushed

### sk.session focus --story <id>
1. Resolve the story per story-lifecycle.md §3: glob `specs/STORY-{id}-*/` (or read its
   `01-story/story.md` frontmatter). Backward compat: a legacy `specs/intents/**/story-{id}.md`
   resolves in place.
2. Set `active_story_id` and `story_dir` (the resolved `STORY-{id}-{name}/` path).
3. Write session.yaml, report current focus.
   (Legacy `--unit <id>` is still accepted for un-migrated repos: set active_unit_id/intent and
   leave active_story_id null.)

### sk.session status
1. Read session.yaml
2. If active_story_id: read `story_dir/01-story/story.md` frontmatter (legacy story file fallback)
3. Report:
   - Role(s) (if set), branch, base branch, session_id
   - Active: story ({story_id}), story_dir, projects_touched
   - Story status and checkpoint_mode
   - If role set: natural commands for that role
   - If role null: all self-asserting commands available; note Group A requires role

### sk.session list [--status <status>]
1. Glob `specs/STORY-*/` (and legacy `specs/intents/**/story-*.md`) for all stories.
2. Read frontmatter from each `01-story/story.md` (or the legacy story file).
3. Display table:
   | ID | Title | Status | Owner | Checkpoint | Branch |
4. Apply filters if provided.
