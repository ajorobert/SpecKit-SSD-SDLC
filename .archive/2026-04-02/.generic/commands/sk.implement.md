<!-- GENERIC LAYER — self-contained command -->
<!-- Before executing: read .generic/hooks/pre-command.md -->
<!-- After executing: read .generic/hooks/post-command.md -->
<!-- Context to load: see .generic/context-maps/command-context-map.md -->

# sk.implement
Executes implementation tasks for a story phase-by-phase.
Story-level command — requires active_story_id

## Pre-flight
1. Read session.yaml active_story_id
   NULL → STOP: run sk.session focus --story {id} first
2. Read story frontmatter — verify status = ready
3. Resolve story directory:
   STORY_DIR = specs/intents/{intent}/units/{unit}/stories/{story-id}/
4. Verify plan.md exists: STORY_DIR/plan.md
   MISSING → STOP: run sk.plan first
5. Verify tasks.md exists: STORY_DIR/tasks.md
   MISSING → STOP: run sk.tasks first

## Context loading (in order)
1. specs/knowledge-base.md (tier 1 — always read first)
2. specs/domains/{relevant-domain}/knowledge-base.md (tier 2 — if exists)
3. specs/intents/{intent}/units/{unit}/knowledge-base.md (tier 3 — if exists)
   Note: knowledge bases contain non-derivable context only (the "why", not the "what")
4. STORY_DIR/plan.md — tech approach, component breakdown, data/API changes
5. STORY_DIR/tasks.md — full task list with phases and parallel markers
6. specs/intents/{intent}/units/{unit}/contracts/api-spec.json (if exists)
7. specs/intents/{intent}/units/{unit}/architecture.md (if exists)
8. .specify/memory/standards/coding-standards.md
9. .specify/memory/standards/observability-standards.md

## Pre-generation protocol
Before writing any code in an existing module:
1. Read the existing code in the target area. Match the established patterns.
2. Search the codebase before introducing a new abstraction (interface, utility, base class) — if an equivalent exists, use it.
This prevents session-to-session drift.

## Project setup verification
Before executing tasks, verify ignore files exist for detected stack:
- Git repo detected → ensure .gitignore exists with correct patterns
- Dockerfile present → ensure .dockerignore exists
Create missing ignore files with standard patterns for the detected technology.

## Task execution (phase-by-phase)
Parse tasks.md and execute phases in order. Do not start a phase until the prior phase is complete.

Standard phase order from tasks.md:
- Phase 1: Setup — project structure, config, dependencies
- Phase 2: Foundational — blocking prerequisites (schema migrations, shared utilities)
- Phase 3+: User story tasks — follow TDD order (test tasks before their implementation tasks)
- Final phase: Cross-cutting concerns (logging, error handling, observability)

For each task:
- Tasks marked [P] may execute in parallel with other [P] tasks in the same phase
- After completing each task: mark it [X] in tasks.md immediately
- If a non-parallel task fails: halt and report with context before proceeding

## Standards enforcement
Flag any coding-standards.md violation immediately.
Do not proceed with that task until the violation is resolved.
Implementation must match contracts/api-spec.json exactly.

## Post-execution
- All tasks marked [X] — verify no unchecked tasks remain
- Confirm tests written before implementation (TDD compliance)
- Story status update handled by post-command hook
- PHR trigger evaluated by post-command hook if novel tradeoffs resolved
