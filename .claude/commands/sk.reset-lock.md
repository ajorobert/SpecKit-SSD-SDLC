sk.reset-lock
Use only when sk.* reports lock exists and no agent session is active.

Steps

1. Read .specify/state.lock — show contents to user
2. Confirm with user before proceeding
3. Delete .specify/state.lock
4. Confirm deletion
5. Show current .specify/state.yaml
