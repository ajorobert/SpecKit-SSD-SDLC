---
name: sk.verify
description: "Invoke when: running the final PASS/FAIL quality gate before sk.ship. Role: architect. Reads: story-{ID}.md, all unit artifacts, architecture-decisions.md, all standards files, governance quality-gates.md. Writes: story status (if PASS)."
subagent_type: SpecKit Architect Agent
inject_files:
  - .claude/session.yaml
  - .specify/memory/architecture-decisions.md
  - .specify/memory/standards/tech-stack.md
  - .specify/memory/standards/coding-standards.md
  - .specify/memory/standards/api-standards.md
  - .specify/memory/standards/data-standards.md
  - .specify/memory/standards/observability-standards.md
  - .claude/skills/governance/SKILL.md
  - .claude/skills/governance/quality-gates.md
---

PASS/FAIL quality gate for active story. Run after sk.test passes, before sk.ship.
Not a mid-implementation check. If you need to verify spec consistency before writing code, use sk.plan --analyze-only.

Read and execute the full workflow in `prompt.md` in this directory.
