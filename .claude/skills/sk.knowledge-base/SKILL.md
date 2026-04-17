---
name: sk.knowledge-base
description: "Invoke when: generating or updating non-derivable context at system, domain, or unit tier. Use --tier system|domain|unit. Role: architect. Reads: session.yaml, existing knowledge-base.md, ADRs. Writes: specs/knowledge-base.md or domain/unit equivalent."
subagent_type: SpecKit Architect Agent
inject_files:
  - .claude/session.yaml
  - .specify/memory/system-context.md
---

Generates or updates knowledge bases. Zero tolerance for content derivable from code.
Tier 1 (system): 300 line hard limit. Tier 2 (domain): 250 lines. Tier 3 (unit): 150 lines.

Read and execute the full workflow in `prompt.md` in this directory.
