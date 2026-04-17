---
name: sk.clarify
description: "Invoke when: resolving story ambiguities before architecture or planning begins. Role: architect. Reads: session.yaml, story-{ID}.md. Writes: story-{ID}.md (clarifications appended)."
subagent_type: SpecKit Architect Agent
inject_files:
  - .claude/session.yaml
---

Resolves ambiguities in the active story using a structured 5-question loop.
Requires active_story_id in session.yaml.

Read and execute the full workflow in `prompt.md` in this directory.
