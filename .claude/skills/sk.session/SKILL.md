---
name: sk.session
description: "Invoke when: starting, ending, switching role, focusing, restoring, or checking status of a development session. Role: any. Reads/writes: session.yaml. Subcommands: start, end, switch, focus, restore, status, list."
inject_files:
  - .claude/session.yaml
  - .specify/memory/standards/story-lifecycle.md
---

Manages local development session state. No subagent — runs inline.
Branch convention + path resolution are canonical in story-lifecycle.md (§3, §5):
base branch defaults to `dev`; branch = feature/{intent-id}/{unit}-{YYYYMMDD}.
One branch = one unit (feature); a session may carry multiple roles, projects, and layer stories.
Subcommands: start [--role], end, switch --role, focus --unit|--story, restore, status, list [--intent] [--status].

Read and execute the full workflow in `prompt.md` in this directory.
