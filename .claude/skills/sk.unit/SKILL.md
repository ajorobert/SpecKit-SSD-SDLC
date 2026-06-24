---
name: sk.unit
description: "Invoke when: defining a feature (unit) within an intent — the lifecycle container. Role: po or lead. Reads: session.yaml, intent.md, projects/index.md. Writes: specs/intents/{intent}/units/{unit}/unit-brief.md + sets active_unit_id/unit_dir."
subagent_type: SpecKit PO Agent
inject_files:
  - .specify/memory/standards/story-lifecycle.md
  - .specify/memory/system-context.md
---

Creates a feature **unit** under an intent. The unit is the lifecycle container — its `stories/`
and numbered phase folders (`02-design` … `07-security-audit`) hold all downstream work. Captures
the feature boundary, user flows, and impacted projects. Writes `unit-brief.md` and focuses the
session on the unit.

Read and execute the full workflow in `prompt.md` in this directory.
