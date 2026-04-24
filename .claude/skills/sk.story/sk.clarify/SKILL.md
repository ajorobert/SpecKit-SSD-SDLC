---
name: sk.clarify
description: "Invoke when: resolving story business ambiguities. Role: po. Mode: PO business rules only. Reads: session.yaml, story-{ID}.md. Writes: story-{ID}.md (clarifications appended)."
subagent_type: SpecKit PO Agent
inject_files:
---

Resolves business ambiguities in the active story using a structured 5-question loop.
Requires active_story_id in session.yaml.

Read and execute the full workflow in `prompt.md` in this directory.
