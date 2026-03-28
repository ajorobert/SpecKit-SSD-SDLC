# Command Rules

## Session
Every sk.* command reads .claude/session.yaml for active focus.
No session active (role null): only sk.session start is permitted.

## Role Behavior
Natural role match: full expert context loaded by agent.
Non-natural role: agent notes mismatch, loads nearest context, proceeds.
No hard blocks on role — session switch recommended for best results.

## Idempotency
Artifact exists → [REFINE MODE] update, never overwrite.
Artifact missing → [CREATE MODE] create from template.
Declare mode at start of every execution.

## Upstream References
Always read .specify/memory/upstream-adapter.md before referencing
any upstream command. Use file paths only, never slash command names.
