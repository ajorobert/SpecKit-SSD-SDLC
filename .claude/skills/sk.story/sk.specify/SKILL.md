---
name: sk.specify
description: "Invoke when: capturing user intent, decomposing to units, creating feature stories, or filing bug reports. Role: po. Reads: session.yaml, system-context.md. Writes: intent.md, unit-brief.md, story-{ID}.md."
subagent_type: SpecKit PO Agent
inject_files:
  - .specify/memory/system-context.md
  - .specify/memory/architecture-decisions.md
  - .specify/memory/domain-model.md
---

Captures intent, decomposes to units and stories.
Mode: `sk.specify --bug` for bug reports, `sk.specify` for features.

Read and execute the full workflow in `prompt.md` in this directory.
