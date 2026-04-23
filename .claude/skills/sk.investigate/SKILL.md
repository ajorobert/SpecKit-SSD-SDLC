---
name: sk.investigate
description: "Invoke when: debugging a story, finding root causes, or classifying bugs as implementation bugs vs spec/contract mismatches. Role: backend or frontend (required). Reads: story-{ID}.md, api-spec.json, plan.md. Writes: investigation-report.md, knowledge-base.md (candidate invariants)."
subagent_type: SpecKit Backend Engineer Agent
inject_files:
---

Spec-aware root-cause debugging. Role determines agent: backend → SpecKit Backend Engineer Agent, frontend → SpecKit Frontend Engineer Agent.
Classifies findings: Implementation Bug vs Spec/Contract Mismatch.

Read and execute the full workflow in `prompt.md` in this directory.
