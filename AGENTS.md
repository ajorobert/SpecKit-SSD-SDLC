# SpecKit-SSD-SDLC

Spec-driven development framework for full-stack multi-service systems.

## For AI Agents — Start Here

Read these files in order before doing anything:
1. .specify/memory/command-rules.md        — rules that govern all skills
2. .specify/memory/system-context.md — what system we are building

## Your Role
Read .generic/personas/{role}.md for your current role context.
If no role assigned, ask the user which role to adopt.

## Available Skills
All sk.* skills live in .claude/skills/
Reference them as: .claude/skills/sk.{skill}/SKILL.md and prompt.md

## Session State
Read and update .generic/session.yaml for active focus.

## Project Memory
.specify/memory/          — system knowledge files
specs/intents/            — all project specs and stories
history/                  — ADR and PHR records

## Context Loading
Before executing any skill, read:
.claude/skills/sk.{skill}/SKILL.md
Load only the inject_files listed in its frontmatter.

## QA and Security Commands
sk.test            — generate and run tests (role: backend-qa | frontend-qa)
sk.security-audit  — OWASP audit, secrets scan, dependency scan (role: security)

QA personas: .generic/personas/backend-qa.md | .generic/personas/frontend-qa.md
Security persona: .generic/personas/security.md

Role routing enforced: sk.test and sk.security-audit check session.yaml role.
Wrong role → STOP with instructions to switch.

## Knowledge Base System
Three-tier non-derivable context alongside code.

Tier 1 — system:  specs/knowledge-base.md
Tier 2 — domain:  specs/domains/{domain}/knowledge-base.md
Tier 3 — unit:    specs/intents/{intent}/units/{unit}/knowledge-base.md

Read before working on any module.
Generated and maintained by sk.knowledge-base skill.
Contains only what cannot be derived from reading code.
