---
name: sk.session
description: "Invoke when: starting, ending, switching role, focusing, restoring, or checking status of a development session. Role: any. Reads/writes: session.yaml. Subcommands: start, end, switch, focus, restore, status, list."
inject_files:
  - .claude/session.yaml
  - .specify/memory/standards/story-lifecycle.md
---

Manages local development session state. No subagent — runs inline.
Branch convention + story-id resolution are canonical in story-lifecycle.md (§3, §5):
base branch defaults to `dev`; branch = feature/{story-id}/{feature-name}-{YYYYMMDD}.
One branch = one story; a session may carry multiple roles and a story multiple projects.
Subcommands: start [--role], end, switch --role, focus --story, restore, status, list [--status].

Read and execute the full workflow in `prompt.md` in this directory.
