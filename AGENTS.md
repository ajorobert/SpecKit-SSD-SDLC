# SpecKit-SSD-SDLC

Spec-driven development framework for full-stack multi-service systems.

## For AI Agents — Start Here

Read these files in order before doing anything:
1. .generic/command-rules.md        — rules that govern all commands
2. .specify/memory/system-context.md — what system we are building
3. .specify/memory/upstream-adapter.md — upstream command references

## Your Role
Read .generic/personas/{role}.md for your current role context.
If no role assigned, ask the user which role to adopt.

## Available Commands
All sk.* commands live in .generic/commands/
Reference them as: .generic/commands/sk.{command}.md

## Session State
Read and update .generic/session.yaml for active focus.

## Project Memory
.specify/memory/          — system knowledge files
specs/intents/            — all project specs and stories
history/                  — ADR and PHR records

## Context Loading
Before executing any command, read:
.generic/context-maps/command-context-map.md
Load only the context files listed for that command.

## QA and Security Commands
sk.test            — generate and run tests (role: backend-qa | frontend-qa)
sk.security-audit  — OWASP audit, secrets scan, dependency scan (role: security)

QA personas: .generic/personas/backend-qa.md | .generic/personas/frontend-qa.md
Security persona: .generic/personas/security.md

Role routing enforced: sk.test and sk.security-audit check session.yaml role.
Wrong role → STOP with instructions to switch.
