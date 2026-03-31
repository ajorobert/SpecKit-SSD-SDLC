<!-- SPECKIT-SSD-SDLC MANAGED -->

# SpecKit-SSD-SDLC

## Identity
Spec-driven development framework for full-stack multi-service systems.
Commands: .claude/commands/sk.*.md
Agents: .claude/agents/
Skills: .claude/skills/ (auto-loaded by context)
Roles: po | architect | lead | backend | frontend | backend-qa | frontend-qa | security

## Rules
1. Read .specify/memory/command-rules.md before any sk.* command
2. upstream/ is a pattern reference archive — not executed at runtime. See upstream-adapter.md for migration rationale.
3. Never edit files inside upstream/
4. Session state: .claude/session.yaml

## Knowledge Bases (non-derivable context)
Tier 1 — system:  specs/knowledge-base.md
Tier 2 — domain:  specs/domains/{domain}/knowledge-base.md
Tier 3 — unit:    specs/intents/{intent}/units/{unit}/knowledge-base.md

Read tier 1 before any work.
Read relevant tier 2 when working within a domain.
Read tier 3 before implementing or testing a unit.
These complement code reading — they contain only what
code cannot tell you.

<!-- END SPECKIT-SSD-SDLC MANAGED -->
