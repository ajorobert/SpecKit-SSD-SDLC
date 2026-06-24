---
name: sk.intent
description: "Invoke when: defining a new business capability (intent) — the top of the spec hierarchy. Role: po. Reads: session.yaml, system-context.md, architecture-decisions.md. Writes: specs/intents/{NNN}-{name}/intent.md + sets active_intent_id."
subagent_type: SpecKit PO Agent
inject_files:
  - .specify/memory/standards/story-lifecycle.md
  - .specify/memory/system-context.md
  - .specify/memory/architecture-decisions.md
---

Creates a business-capability intent at the top of the intent → unit → story hierarchy.
One intent = one coherent business capability (e.g. Authentication, Checkout). Writes
`specs/intents/{intent-id}/intent.md` and focuses the session on it.

Read and execute the full workflow in `prompt.md` in this directory.
