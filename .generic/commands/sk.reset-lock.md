<!-- GENERIC LAYER — self-contained command -->
<!-- Before executing: read .generic/hooks/pre-command.md -->
<!-- After executing: read .generic/hooks/post-command.md -->
<!-- Context to load: see .generic/context-maps/command-context-map.md -->

# sk.reset-lock
Use only when sk.* reports lock exists and no other agent session is active.

## Steps
1. Read .claude/session.lock — show contents to user
2. Confirm with user before proceeding
3. Delete .claude/session.lock
4. Confirm deletion
5. Show current .claude/session.yaml