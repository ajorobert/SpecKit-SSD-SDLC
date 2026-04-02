<!-- GENERIC LAYER — self-contained command -->
<!-- Before executing: read .generic/hooks/pre-command.md -->
<!-- After executing: read .generic/hooks/post-command.md -->
<!-- Context to load: see .generic/context-maps/command-context-map.md -->

# sk.constitution
Initializes or updates project principles and standards via an interview flow.
Runs once at project initialization (or to update principles).

## Pre-flight
1. Check if .specify/memory/constitution.md exists:
   EXISTS → [REFINE MODE] update existing
   MISSING → [CREATE MODE] create from interview
2. Load skill: .claude/skills/system-context/SKILL.md

## CREATE MODE — Interview flow
Collect values interactively. Offer a suggested answer if inferable from
existing repo context (README, system-context.md, tech-stack.md).

1. System name & purpose — one sentence
2. Primary actors — users, services, admins
3. Non-negotiable constraints — tech mandates, compliance, deployment restrictions
4. Tech philosophy — e.g., simplicity-first, event-driven, API-first, DDD
5. Deployment context — on-premise, cloud, containerized, hybrid

After all items collected: write .specify/memory/constitution.md

## REFINE MODE
Load existing constitution.md.
Identify unfilled [ALL_CAPS_IDENTIFIER] placeholders and collect values.
Increment CONSTITUTION_VERSION:
- MAJOR: principle removals or redefinitions
- MINOR: new principle or section added
- PATCH: wording clarifications or typo fixes

## constitution.md structure
```
# Project Constitution
Version: {X.Y.Z} | Ratification: {YYYY-MM-DD} | Last Amended: {YYYY-MM-DD}

## System Identity
## Primary Actors
## Non-Negotiable Constraints
## Tech Philosophy
## Deployment Context
## Governance
```

Principles must be declarative and testable. No vague language.

## Post-execution
Prompt user to verify or populate:
- .specify/memory/system-context.md
- .specify/memory/standards/tech-stack.md

Update session.yaml:
- last_command: sk.constitution
- last_command_at: <timestamp>
- last_command_status: success
