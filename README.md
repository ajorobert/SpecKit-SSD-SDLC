# SpecKit-SSD-SDLC

A spec-driven development framework for full-stack multi-service systems.
Built as a structured layer on top of [github/spec-kit](https://github.com/github/spec-kit).

---

## What This Is

SpecKit-SSD-SDLC gives a team of AI agents — and the humans working with them —
a shared, structured process for going from business intent to working code.

It enforces a hierarchy of artifacts (Intent → Unit → Story), a team-based session
model with role-specific agents, adaptive quality checkpoints, and a full SDLC
workflow from specification through implementation and verification.

It works with Claude Code natively. Google Antigravity (Gemini) is supported
via GEMINI.md, which routes into the same `.claude/` command and agent layer.

---

## What The Framework Adds Over Plain spec-kit

| Gap in spec-kit | SpecKit-SSD-SDLC solution |
|-----------------|--------------------------|
| No architecture step | sk.architecture, sk.datamodel, sk.contracts |
| No system context awareness | Memory layer + skills auto-loading |
| No multi-service thinking | Service registry + domain model + impact analysis |
| No team workflow | Session model + role-based agents + branch management |
| No quality gates | 6-phase PASS/FAIL gates + sk.verify |
| No decision history | ADR + PHR systems |
| No QA layer | sk.test with backend-qa and frontend-qa agents |
| No security layer | sk.security-audit with security agent |
| No non-derivable context | Three-tier knowledge base system |
| Single tool dependency | Generic layer for any agent |
| No upstream resilience | Subtree + reconcile script + adapter map |
| No project bootstrap | setup.sh + sk.init for one-command initialization |

---

## Four-Source Map

This framework draws from four sources:

| Source | What is taken | Where it lives |
|--------|--------------|----------------|
| **spec-kit** | AI prompting patterns (clarify loop, implement phases, constitution interview) | Inlined into sk.* commands — `upstream/` is a reference archive only |
| **spec-kit-plus** | ADR system, PHR system, PASS/FAIL quality gates, command-rules pattern | `sk.adr`, `sk.phr`, `sk.verify`, `.specify/memory/command-rules.md` |
| **specs.md** (concepts) | Intent→Unit→Story hierarchy, adaptive checkpoints, hierarchical standards, complexity classification | `specs/intents/`, `.claude/skills/governance/`, `.specify/memory/standards/` |
| **gstack** | Execution pipeline (code review, browser QA, eng review, debugging, shipping) | `sk.review`, `sk.plan-eng-review`, `sk.qa`, `sk.investigate`, `sk.ship` wrappers |

The spec-kit upstream is a reference archive — never executed at runtime. All AI prompting patterns
have been inlined into sk.* commands adapted to our artifact structure.
gstack must be installed separately: see [github.com/garrytan/gstack](https://github.com/garrytan/gstack).

---

## Execution Layer

### Claude Code Native — `.claude/`
Lean commands that use Claude Code primitives: skills auto-loaded by context,
a post-command hook for story status updates, and agent persona definitions.
Commands are concise (Input Artifacts / Steps / Output Artifacts / Quality Bar).

### Antigravity (Gemini) — `GEMINI.md`
GEMINI.md routes Antigravity into the same `.claude/` commands, agents, and skills.
No separate command layer — zero duplication. Entry point: `GEMINI.md`.

---

## What Was Built

### Foundation

- `upstream/` — spec-kit as a protected git subtree. Never edited. Pulled via `git subtree pull` when upstream releases.
- Unified Architecture: `.claude/` is the master execution layer for both Claude Code and Antigravity (Gemini). GEMINI.md routes Gemini into the same layer.
- Root entry points: `CLAUDE.md`, `GEMINI.md`

### Memory Layer (`.specify/memory/`)

- `system-context.md` — what system is being built
- `domain-model.md` — canonical domain entities
- `service-registry.md` — all services and their contracts
- `architecture-decisions.md` — ADR index
- `command-rules.md` — agent behavior rules
- `gemini-command-rules.md` — agent behavior rules for Antigravity (Gemini), kept separate to avoid bloating Claude context
- `upstream-adapter.md` — upstream file path references
- `standards/` — tech stack, coding, API, data standards with module overrides

### 28 Commands (`.claude/commands/`)

| Type | Commands |
|------|----------|
| Spec & planning | sk.constitution, sk.specify, sk.clarify, sk.architecture, sk.datamodel, sk.contracts, sk.plan, sk.tasks, sk.implement, sk.analyze, sk.ff |
| Validation | sk.impact, sk.verify |
| gstack wrappers | sk.office-hours [optional], sk.plan-eng-review, sk.review, sk.investigate, sk.qa, sk.ship |
| QA & Security | sk.test, sk.security-audit |
| History | sk.adr, sk.phr |
| Knowledge | sk.knowledge-base |
| Session | sk.session, sk.reset-lock |
| Init | sk.init |

### 8 Agent Personas (`.claude/agents/`)

- po, architect, lead
- backend, frontend
- backend-qa, frontend-qa
- security

### 7 Skills (`.claude/skills/`)

- system-context, domain-model, service-registry
- architecture-decisions, standards, upstream-adapter, governance

### Governance (`.claude/skills/governance/`)

- 12-phase SDLC flow with parallel execution
- Adaptive checkpoints: autopilot / confirm / validate
- 6 quality gates: spec, architecture, plan, implementation, test, security
- Role ownership per phase
- PASS/FAIL verification via sk.verify

### Session Model (`.claude/session.yaml`, gitignored)

- Role-based sessions with `sk.session start/switch/end/focus/status/list`
- Branch-per-session with auto-commit and PR on end
- Story status tracked in frontmatter: draft → ready → in-progress → testing → security-review → review → done

### History Layer

- ADR system: `history/adr/` with `create-adr.sh`
- PHR system: `history/prompts/` with `create-phr.sh`
- Reconcile script: `reconcile-upstream.sh` with exclusion list

### Knowledge Base System (`specs/`)

- Tier 1: system-level non-derivable context
- Tier 2: core domain knowledge bases
- Tier 3: unit-level knowledge bases
- Complements code reading — contains only what code cannot tell you

### Templates (`templates/artifacts/`)

- intent, unit-brief, story
- architecture, contracts-readme
- adr, phr
- test-plan, security-audit
- system / domain / unit knowledge base

---

## Using SpecKit in Your Project

SpecKit is designed to be added as a **git subtree** to any project repository.
A `setup.sh` script deploys the framework files, and `sk.init` initializes project memory.

### Step 1 — Add as subtree

```bash
git subtree add --prefix=.speckit https://github.com/your-org/SpecKit-SSD-SDLC main --squash
```

### Step 2 — Run setup

```bash
bash .speckit/setup.sh
```

This script:
- **Always:** Syncs `.claude/` to your project root (framework-owned)
- **On first run:** Creates `CLAUDE.md`, `GEMINI.md`, `.specify/`, `specs/`, `history/`
- **On update runs:** Prompts whether to replace `CLAUDE.md`/`GEMINI.md` with latest — your answer, no default

Your project-specific config (`.specify/project-config.md`) is **never touched** by setup.sh.

### Step 3 — Initialize project memory

```bash
/sk.init    # in Claude Code
```

`sk.init` interviews you about your project and generates:
- `.specify/project-config.md` — project identity + custom rules (shared by CLAUDE.md and GEMINI.md)
- `.specify/memory/system-context.md`, `service-registry.md`
- `.specify/memory/standards/` — tech stack, coding standards, API standards, data standards

Run `sk.init` again at any time to update specific memory files.

### Receiving Framework Updates

```bash
git subtree pull --prefix=.speckit https://github.com/your-org/SpecKit-SSD-SDLC main --squash
bash .speckit/setup.sh    # updates .claude/; prompts for CLAUDE.md/GEMINI.md
```

### What lives where after setup

```
your-monorepo/
├── .speckit/                   ← framework subtree (don't edit)
├── .claude/                    ← deployed by setup.sh, commit this
├── .specify/
│   ├── project-config.md       ← yours (generated by sk.init, edit freely)
│   └── memory/                 ← yours (generated by sk.init)
├── specs/                      ← yours (your intents, units, stories)
├── history/                    ← yours (ADRs, PHRs)
├── CLAUDE.md                   ← framework template (update via setup.sh prompt)
└── GEMINI.md                   ← framework template (update via setup.sh prompt)
```

---

## How To Use It

### 1. Initialize your project

```bash
git subtree add --prefix=.speckit <url> main --squash
bash .speckit/setup.sh
/sk.init    # interview → generates all memory files
```

### 2. Start a session

```
sk.session start --role po
```

### 3. Run the SDLC

```
[sk.office-hours]   ← [optional] validate idea before spec work (po/architect)
sk.specify          ← captures intent, unit, story; classifies checkpoint
sk.clarify          ← resolve questions
sk.architecture     ← (validate mode only, or when new services involved)
[sk.plan-eng-review]← [optional] engineer review of architecture (architect)
sk.plan             ← technical plan
sk.tasks            ← task breakdown
sk.implement        ← build
sk.review           ← spec-aware code review: bounded context + contracts + ADRs
sk.verify           ← quality gate
sk.test             ← generate and run tests (backend-qa or frontend-qa role)
sk.qa               ← browser acceptance testing (frontend-qa role only)
sk.security-audit   ← OWASP + STRIDE audit, secrets scan (security role)
sk.ship             ← quality-gated release (lead role; sk.verify must pass)
```

Or for standard features:

```
sk.ff               ← runs specify→clarify→architecture→plan→tasks in one shot
```

> **Prerequisite for sk.review, sk.qa, sk.investigate, sk.plan-eng-review, sk.ship, sk.office-hours:**
> gstack must be installed. See [github.com/garrytan/gstack](https://github.com/garrytan/gstack).

### What To Do Next

**Immediate — before using on a real project:**

1. Run `bash .speckit/setup.sh` to deploy the framework
2. Run `/sk.init` to interview and generate all memory files
3. Run `sk.session start --role po` and begin with `sk.specify`

**Before the first real story ships:**

- Define core domains via `sk.knowledge-base --tier domain`
- Establish auth ADR early — everything depends on it
- Set coverage thresholds in `.specify/memory/standards/coding-standards.md`

**Ongoing:**

- Pull framework updates: `git subtree pull --prefix=.speckit <url> main --squash && bash .speckit/setup.sh`
- Pull upstream updates: `git subtree pull --prefix upstream https://github.com/github/spec-kit.git main --squash`
- Run `bash scripts/reconcile-upstream.sh` after every upstream pull
- Update knowledge bases after every ADR
- Run `sk.session list` as your team's daily standup view

---

## Reference

### Commands

| Command | Level | Role | Description |
|---------|-------|------|-------------|
| `sk.constitution` | project | any | Initialize or update project principles via interview; writes constitution.md |
| `sk.specify` | intent→story | po | Capture intent, decompose to unit and story |
| `sk.clarify` | story | po/architect/lead | Resolve ambiguities before planning |
| `sk.impact` | intent | architect | Assess blast radius of proposed work |
| `sk.architecture` | unit | architect | Define service boundaries, one doc per unit |
| `sk.datamodel` | unit | architect | Define data model, one doc per unit |
| `sk.contracts` | unit | architect | Define API contracts, generate provider tests |
| `sk.plan` | story | lead | Technical implementation plan |
| `sk.tasks` | story | lead | Actionable task breakdown (TDD order) |
| `sk.implement` | story | backend/frontend | Execute tasks phase-by-phase (TDD order, marks [X] per task) |
| `sk.review` | story | backend/frontend | Spec-aware code review: bounded context + contracts + ADRs → gstack /review |
| `sk.verify` | story | architect/lead | PASS/FAIL quality gate across all gates |
| `sk.ff` | story | lead | Fast-forward: specify→clarify→architecture→plan→tasks |
| `sk.adr` | unit/intent | architect | Create Architecture Decision Record |
| `sk.phr` | story/unit | any | Record Prompt History for significant decisions |
| `sk.knowledge-base` | system/domain/unit | architect | Generate or update knowledge base at specified tier |
| `sk.test` | story | backend-qa / frontend-qa | Generate and run test suite (provider contract + integration, or consumer contract + E2E + component) |
| `sk.qa` | story | frontend-qa | Browser acceptance testing mapped to AC → gstack /qa (frontend only) |
| `sk.security-audit` | story | security | OWASP Top 10 + STRIDE audit, secrets scan, dependency scan — writes security-audit.md |
| `sk.ship` | story | lead | Quality-gated release: sk.verify must pass → gstack /ship |
| `sk.office-hours` | intent/unit | po/architect | [OPTIONAL] Validate product idea or feature approach → gstack /office-hours |
| `sk.plan-eng-review` | unit | architect | [OPTIONAL] Validate engineering plan against service-registry + ADRs → gstack /plan-eng-review |
| `sk.investigate` | story | backend/frontend | Spec-aware debugging: classifies findings as implementation bug vs spec deviation → gstack /investigate |
| `sk.session` | — | any | Manage local session: start/end/focus/status/list/switch |
| `sk.analyze` | unit | lead/architect | Cross-artifact consistency check (stories, contracts, bounded context, ADRs) |
| `sk.reset-lock` | — | any | Clear stuck session lock |
| `sk.init` | — | any | Initialize or update project memory via interview; generates `.specify/project-config.md` and all `.specify/memory/` files |

---

### Team Session Model

Each team member runs a local session with a role:

```
sk.session start --role architect
sk.session focus --unit CHK-PAY
sk.architecture
sk.datamodel
sk.contracts
sk.session end               ← commits, pushes branch, opens PR
```

Roles: `po` · `architect` · `lead` · `backend` · `frontend` · `backend-qa` · `frontend-qa` · `security`

Session state (`.claude/session.yaml`) is gitignored — each person's focus
is local. Shared state lives in `specs/` story frontmatter and `.specify/memory/`.

---

### Adaptive Checkpoints

Each story is classified at specify-time into one of three modes:

| Mode | Trigger | Behaviour |
|------|---------|-----------|
| `autopilot` | Isolated change, no contract changes, no new entities | No pauses — sk.ff runs end-to-end |
| `confirm` | New feature in existing bounded context | Pause after sk.plan for approval |
| `validate` | New service, breaking contracts, cross-cutting concerns | Pause after sk.architecture AND after sk.plan |

---

### Quality Gates

`sk.verify` evaluates six gates in sequence:

| Gate | Runs when | Key checks |
|------|-----------|-----------|
| **Spec** | always | intent exists, acceptance criteria written, no undefined dependencies |
| **Architecture** | if architecture.md exists | stories covered, services registered, domain entities added, ADR for cross-service decisions |
| **Plan** | if plan.md exists | contracts defined for new endpoints, checkpoint approved if required |
| **Implementation** | if tasks complete | all tasks done, PHR created, no standards violations |
| **Test** | before `security-review` | provider + consumer contract tests exist, every AC has E2E, coverage thresholds met, all tests pass |
| **Security** | before `done` | security-audit.md exists, OWASP Top 10 documented, STRIDE table present, no open CRITICAL findings (OWASP or STRIDE), secrets scan clean |

A single FAIL blocks progression. Security verdict BLOCKED prevents the story from reaching `done`.

---

### Agent Personas

Eight agents, each scoped to specific commands and files:

- **po** — defines intents, units, stories, acceptance criteria
- **architect** — service design, data models, contracts, ADRs, knowledge bases
- **lead** — implementation plans, task breakdowns, consistency checks
- **backend-engineer** — API and data layer implementation
- **frontend-engineer** — UI and frontend logic implementation
- **backend-qa** — provider contract tests, integration tests, coverage validation
- **frontend-qa** — consumer contract tests, E2E tests, component tests, accessibility
- **security** — OWASP Top 10 audit, secrets scan, dependency scan, security-audit.md

Constraints are hard-coded per persona: QA agents never modify implementation code;
security agent never modifies implementation code or specs; backend-engineer never
modifies `specs/` or `contracts/`; architect never writes to `src/`.

---

### Updating Upstream

```bash
git subtree pull --prefix upstream https://github.com/github/spec-kit.git main --squash
bash scripts/reconcile-upstream.sh
```

`reconcile-upstream.sh` checks all paths in `.specify/memory/upstream-adapter.md` and reports
broken references or new upstream files that may need wrapper commands.
Reports are written to `history/reconcile-reports/` (gitignored).

Never edit files inside `upstream/` directly.

---

### Repository Structure

```
upstream/                      ← spec-kit source (read-only, git subtree)

.claude/                       ← Claude Code + Antigravity execution layer
  commands/sk.*.md             ← 28 sk.* commands (including sk.init)
  agents/                      ← 8 role-based agent personas
  skills/                      ← context skills (auto-loaded by Claude Code)
  hooks/                       ← archive-file.sh, post-command.md, validate-path.sh
  settings.json                ← security policies and hook config
  session.yaml                 ← local session state (gitignored)

templates/                     ← deployment templates (used by setup.sh)
  root/                        ← CLAUDE.md, GEMINI.md, .gitignore.fragment
  project/                     ← .specify/, specs/, history/ scaffolding
  artifacts/                   ← adr, phr, architecture, contracts, story, unit, intent,
                               ←   test-plan, security-audit, knowledge base (3 tiers)

scripts/                       ← utility scripts
  create-adr.sh                ← numbered ADR file creation
  create-phr.sh                ← numbered PHR file creation
  reconcile-upstream.sh        ← upstream change detection

.specify/                      ← project knowledge (generated by sk.init)
  project-config.md            ← project identity + custom rules (shared by CLAUDE.md + GEMINI.md)
  memory/
    system-context.md          ← what system you're building
    domain-model.md            ← canonical entities
    service-registry.md        ← service contracts
    architecture-decisions.md  ← ADR index
    upstream-adapter.md        ← upstream file path map
    command-rules.md           ← agent behavior rules (Claude Code)
    gemini-command-rules.md    ← agent behavior rules (Antigravity)
    standards/                 ← tech-stack, coding, API, data, per-module

specs/                         ← living project specs
  knowledge-base.md            ← tier 1: system-level non-derivable context
  domains/                     ← tier 2: core domain knowledge bases
  intents/                     ← Intent → Unit → Story hierarchy

history/
  adr/                         ← Architecture Decision Records
  prompts/                     ← Prompt History Records

setup.sh                       ← deployment script (run after git subtree add/pull)
CLAUDE.md                      ← Claude Code entry point (framework-managed template)
GEMINI.md                      ← Antigravity entry point (framework-managed template)
```

---

### Spec Hierarchy

```
Intent (e.g. CHK)
└── Unit (e.g. CHK-PAY)
    ├── architecture.md        ← unit-level, covers all stories
    ├── data-model.md          ← unit-level
    ├── knowledge-base.md      ← unit-level non-derivable context (tier 3)
    ├── contracts/             ← unit-level API spec + tests
    └── stories/
        └── story-CHK-PAY-001.md   ← frontmatter: status, checkpoint_mode
            ├── plan.md            ← story-level
            └── tasks.md           ← story-level
```

Stories carry structured frontmatter: `status` (draft → ready → in-progress →
review → testing → security-review → done), `checkpoint_mode`
(autopilot / confirm / validate), `checkpoint_status`, `owner`, `branch`,
`test-status` (null / pass / fail), and `security-status` (null / CLEAR / CONDITIONAL / BLOCKED).

---

### Gitignored Runtime Files

```
.claude/session.yaml           ← local session focus (per-developer)
.claude/session.lock           ← runtime lock (cleared after each command)
history/reconcile-reports/     ← upstream reconcile output
```
