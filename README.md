# SpecKit-SSD-SDLC

A spec-driven development framework for full-stack multi-service systems.
Built as a structured layer on top of [github/spec-kit](https://github.com/github/spec-kit).

## What This Is

SpecKit-SSD-SDLC gives a team of AI agents — and the humans working with them —
a shared, structured process for going from business intent to working code.

It enforces a hierarchy of artifacts (Intent → Unit → Story), a team-based session
model with role-specific agents, adaptive quality checkpoints, and a full SDLC
workflow from specification through implementation and verification.

It works with Claude Code natively, and includes a platform-agnostic layer
for Cursor, Windsurf, Gemini CLI, Codex, and any tool that reads markdown.

---

## Three-Source Map

This framework draws from three sources:

| Source | What is taken | Where it lives |
|--------|--------------|----------------|
| **spec-kit** | Core workflow engine (specify, plan, tasks, implement, clarify, analyze) | `upstream/` subtree + `sk.*` wrappers |
| **spec-kit-plus** | ADR system, PHR system, PASS/FAIL quality gates, command-rules pattern | `sk.adr`, `sk.phr`, `sk.verify`, `.specify/memory/command-rules.md` |
| **specs.md** (concepts) | Intent→Unit→Story hierarchy, adaptive checkpoints, hierarchical standards, complexity classification | `specs/intents/`, `.claude/skills/governance/`, `.specify/memory/standards/` |

The spec-kit upstream is never modified. All framework logic lives in the layer above it.

---

## Two Execution Layers

### Claude Code Native — `.claude/`
Lean commands that use Claude Code primitives: skills auto-loaded by context,
a post-command hook for story status updates, and agent persona definitions.
Commands are concise (Input Artifacts / Steps / Output Artifacts / Quality Bar).

### Generic — `.generic/`
Self-contained commands that carry all context-loading instructions inline.
Works with any AI tool that reads markdown. Entry points: `AGENTS.md`,
`.cursorrules`, `.windsurfrules`, `GEMINI.md`.

---

## Repository Structure

```
upstream/                      ← spec-kit source (read-only, git subtree)

.claude/                       ← Claude Code native layer
  commands/sk.*.md             ← 17 lean sk.* commands
  agents/                      ← 5 role-based agent personas
  skills/                      ← 7 context skills (auto-loaded)
  hooks/post-command.md        ← story status updates after each command
  session.yaml                 ← local session state (gitignored)

.generic/                      ← platform-agnostic layer
  commands/sk.*.md             ← same 17 commands, self-contained
  personas/                    ← role definitions for generic tools
  context-maps/                ← explicit context-loading instructions
  hooks/                       ← pre/post command instructions (inline)

.specify/                      ← project knowledge (fill in for your project)
  memory/
    system-context.md          ← what system you're building
    domain-model.md            ← canonical entities
    service-registry.md        ← service contracts
    architecture-decisions.md  ← ADR index
    upstream-adapter.md        ← upstream file path map
    command-rules.md           ← agent behavior rules
    standards/                 ← tech-stack, coding, API, data, per-module

specs/                         ← living project specs
  intents/                     ← Intent → Unit → Story hierarchy

.your-layer/                   ← framework internals
  templates/                   ← adr, phr, architecture, contracts, story, unit, intent
  scripts/                     ← create-adr.sh, create-phr.sh, reconcile-upstream.sh

history/
  adr/                         ← Architecture Decision Records
  prompts/                     ← Prompt History Records

CLAUDE.md                      ← Claude Code entry point
AGENTS.md                      ← Generic tools entry point
.cursorrules / .windsurfrules / GEMINI.md  ← Tool-specific entry points
```

---

## Spec Hierarchy

```
Intent (e.g. CHK)
└── Unit (e.g. CHK-PAY)
    ├── architecture.md        ← unit-level, covers all stories
    ├── data-model.md          ← unit-level
    ├── contracts/             ← unit-level API spec + tests
    └── stories/
        └── story-CHK-PAY-001.md   ← frontmatter: status, checkpoint_mode
            ├── plan.md            ← story-level
            └── tasks.md           ← story-level
```

Stories carry structured frontmatter: `status`, `checkpoint_mode`
(autopilot / confirm / validate), `checkpoint_status`, `owner`, `branch`.

---

## Adaptive Checkpoints

Each story is classified at specify-time into one of three modes:

| Mode | Trigger | Behaviour |
|------|---------|-----------|
| `autopilot` | Isolated change, no contract changes, no new entities | No pauses — sk.ff runs end-to-end |
| `confirm` | New feature in existing bounded context | Pause after sk.plan for approval |
| `validate` | New service, breaking contracts, cross-cutting concerns | Pause after sk.architecture AND after sk.plan |

---

## Commands

| Command | Level | Role | Description |
|---------|-------|------|-------------|
| `sk.constitution` | project | any | Initialize project principles and fill memory files |
| `sk.specify` | intent→story | po | Capture intent, decompose to unit and story |
| `sk.clarify` | story | po/architect/lead | Resolve ambiguities before planning |
| `sk.impact` | intent | architect | Assess blast radius of proposed work |
| `sk.architecture` | unit | architect | Define service boundaries, one doc per unit |
| `sk.datamodel` | unit | architect | Define data model, one doc per unit |
| `sk.contracts` | unit | architect | Define API contracts, generate provider tests |
| `sk.plan` | story | lead | Technical implementation plan |
| `sk.tasks` | story | lead | Actionable task breakdown (TDD order) |
| `sk.implement` | story | backend/frontend | Execute tasks via upstream implement |
| `sk.verify` | story | architect/lead | PASS/FAIL quality gate across all gates |
| `sk.ff` | story | lead | Fast-forward: specify→clarify→architecture→plan→tasks |
| `sk.adr` | unit/intent | architect | Create Architecture Decision Record |
| `sk.phr` | story/unit | any | Record Prompt History for significant decisions |
| `sk.session` | — | any | Manage local session: start/end/focus/status/list/switch |
| `sk.analyze` | unit | lead/architect | Cross-artifact consistency check |
| `sk.reset-lock` | — | any | Clear stuck session lock |

Upstream commands (specify, plan, tasks, implement, clarify, analyze) are delegated
via path references in `.specify/memory/upstream-adapter.md` — never by slash command name.

---

## Team Session Model

Each team member runs a local session with a role:

```
sk.session start --role architect
sk.session focus --unit CHK-PAY
sk.architecture
sk.datamodel
sk.contracts
sk.session end               ← commits, pushes branch, opens PR
```

Roles: `po` · `architect` · `lead` · `backend` · `frontend`

Session state (`.claude/session.yaml`) is gitignored — each person's focus
is local. Shared state lives in `specs/` story frontmatter and `.specify/memory/`.

---

## Quality Gates

`sk.verify` evaluates four gates in sequence:

| Gate | Runs when | Key checks |
|------|-----------|-----------|
| **Spec** | always | intent exists, acceptance criteria written, no undefined dependencies |
| **Architecture** | if architecture.md exists | stories covered, services registered, domain entities added, ADR for cross-service decisions |
| **Plan** | if plan.md exists | contracts defined for new endpoints, checkpoint approved if required |
| **Implementation** | if tasks complete | all tasks done, PHR created, no standards violations |

A single FAIL blocks progression. PASS sets story status to `done`.

---

## Agent Personas

Five agents, each scoped to specific commands and files:

- **po** — defines intents, units, stories, acceptance criteria
- **architect** — service design, data models, contracts, ADRs
- **lead** — implementation plans, task breakdowns, consistency checks
- **backend-engineer** — API and data layer implementation
- **frontend-engineer** — UI and frontend logic implementation

Constraints are hard-coded per persona: e.g. backend-engineer never modifies
`specs/` or `contracts/`; architect never writes to `src/`.

---

## Setup

### 1. Fill in project memory

These two files must be populated before any `sk.*` command runs:

```
.specify/memory/system-context.md
.specify/memory/standards/tech-stack.md
```

Run `sk.constitution` first — it executes the upstream constitution workflow
then prompts you to fill in these files.

### 2. Start a session

```
sk.session start --role po
```

### 3. Run the SDLC

```
sk.specify          ← captures intent, unit, story; classifies checkpoint
sk.clarify          ← resolve questions
sk.architecture     ← (validate mode only, or when new services involved)
sk.plan             ← technical plan
sk.tasks            ← task breakdown
sk.implement        ← build
sk.verify           ← quality gate
```

Or for standard features:

```
sk.ff               ← runs specify→clarify→architecture→plan→tasks in one shot
```

---

## Updating Upstream

```bash
git subtree pull --prefix upstream https://github.com/github/spec-kit.git main --squash
.your-layer/scripts/reconcile-upstream.sh
```

`reconcile-upstream.sh` checks all paths in `upstream-adapter.md` and reports
broken references or new upstream files that may need wrapper commands.
Reports are written to `.your-layer/reconcile-reports/` (gitignored).

Never edit files inside `upstream/` directly.

---

## Gitignored Runtime Files

```
.claude/session.yaml      ← local session focus
.claude/session.lock      ← runtime lock (cleared after each command)
.generic/session.yaml     ← generic layer session focus
.specify/state.lock       ← legacy (kept for safety)
.your-layer/reconcile-reports/
```
