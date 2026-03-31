# sk.constitution
Initializes or updates project principles and standards via an interview flow.
Role: any | Level: project

## Mode detection
- .specify/memory/constitution.md EXISTS → [REFINE MODE] update existing
- .specify/memory/constitution.md MISSING → [CREATE MODE] create from interview
Declare mode at start of execution.

## Interview flow (CREATE MODE)
Collect values interactively. For each item, offer a suggested answer if inferable from
existing repo context (README, system-context.md, tech-stack.md).

1. **System name & purpose**
   What is this system called, and what is its primary purpose in one sentence?

2. **Primary actors**
   Who are the main actors interacting with the system? (users, services, admins)

3. **Non-negotiable constraints**
   What constraints are absolutely fixed — technology mandates, compliance requirements,
   deployment restrictions, or organizational policies that cannot be changed?

4. **Tech philosophy**
   What is the team's primary engineering philosophy?
   (e.g., simplicity-first, event-driven, API-first, CQRS, DDD, microservices)

5. **Deployment context**
   Where and how will this system run?
   (e.g., on-premise, cloud provider, containerized, serverless, hybrid)

After each answer: record in working memory.
After all 5 items collected: write .specify/memory/constitution.md.

## REFINE MODE
Load existing .specify/memory/constitution.md.
Identify every placeholder token of the form [ALL_CAPS_IDENTIFIER] still unfilled.
For each unfilled placeholder: ask a targeted question to collect the value.
Increment CONSTITUTION_VERSION:
- MAJOR: principle removals or redefinitions
- MINOR: new principle or section added
- PATCH: wording clarifications, typo fixes

## constitution.md structure
Write with these sections:
```
# Project Constitution
Version: {X.Y.Z} | Ratification: {YYYY-MM-DD} | Last Amended: {YYYY-MM-DD}

## System Identity
{name} — {purpose}

## Primary Actors
{list of actors with brief role description}

## Non-Negotiable Constraints
{numbered list — each item: declarative, testable, no vague language}

## Tech Philosophy
{paragraph describing engineering approach and key principles}

## Deployment Context
{paragraph describing runtime environment and operational model}

## Governance
Amendment procedure: changes require explicit sk.constitution invocation.
Compliance review: sk.verify checks constitution constraints at each quality gate.
```

Principles must be declarative and testable. Replace "should" with MUST or MAY where appropriate.
Remove vague adjectives — replace with measurable criteria or explicit targets.

## Post-write
Prompt user to verify or populate:
- .specify/memory/system-context.md (system overview, key stakeholders, business context)
- .specify/memory/standards/tech-stack.md (runtime versions, primary libraries, toolchain)

Suggest: `sk.knowledge-base --tier system` as next step if starting a new project.

## Output Artifacts
.specify/memory/constitution.md (written or updated)

## Quality Bar
- No [PLACEHOLDER] tokens remaining (or explicitly marked TODO with rationale)
- All principles declarative and testable
- Version number incremented if content changed
- System context populated before any other sk.* command runs
