# Evals, Policies & Guardrails — Findings, Proposals & Staged Implementation Plan

**Date:** 2026-07-13
**Scope:** The framework's entire quality-enforcement surface — hooks (`.claude/hooks/`), governance (`.claude/skills/governance/`), skill frontmatter contracts (`rubric:`, `preconditions:`), agent write-scopes (`.claude/agents/`), permission rules (`.claude/settings.json`), telemetry (`cache-metrics.jsonl`), and the distribution path (`setup.sh`).
**Lens:** This repo IS the framework. Every mechanism proposed here must either (a) ship automatically to consuming projects, or (b) protect the framework's own evolution so consuming projects inherit a *correct* framework. A proposal that benefits neither is out of scope.
**Objective:** Decide whether — and in what shape — **evals**, **policies**, and **guardrails** should be added, so that any project adopting the framework benefits from them out of the box.

---

## 1. Verdict

**Yes to all three pillars — but deliberately thin, and in a specific order: repair before extend.**

- The framework already has all three pillars *in embryo*: guardrails (delete-interception, path validation, role write-scopes), policies (declarative skill preconditions + a story-status state machine), and evals (rubric blocks, quality gates, cache telemetry).
- The **policy tier is currently broken** — six verified defects (§4) mean the state machine no-ops (its stderr warnings surface nowhere), the flagship ship-gate can only ever block, one precondition check can only ever pass, and two roles have no write-scope enforcement at all. Anything built on top inherits the breakage, so repair is Stage 0 and non-negotiable.
- The **eval tier is the thinnest**: there is *zero* regression detection for skill/prompt edits, which is the framework's core product. Every prompt refactor (including the in-flight prompt-cache optimization) is flown blind.
- The **guardrail tier is the strongest** today, but several guardrails documented as enforced are actually prose-only (loop limits, comment-marker greppability, PII deny-list).

In simple words:

- **Guardrails** = "the agent physically cannot do the dangerous thing" (deterministic hooks, zero tokens, always-on). Mostly present; extend selectively.
- **Policies** = "work cannot advance until declared conditions hold" (declarative rules + state machine, zero tokens, always-on). Present but broken; repair, then extend into policies-as-code.
- **Evals** = "we can measure whether a change made outputs better or worse" (fixtures + scoring, costs tokens, on-demand). Absent; build small.

**Who benefits, and how it propagates:** consuming projects install the framework via `git subtree` + `bash .speckit/setup.sh`, whose Phase 1 **always rsyncs `.claude/`** — skills, hooks, `settings.json`, governance — into the project root ([setup.sh:29-42](../setup.sh#L29-L42)). Every hook, policy file, and guardrail added to this repo therefore lands in every consuming project on its next `setup.sh` run, with no per-project work. Evals are the exception: they live dev-side in this repo (framework authors), and their benefit reaches projects indirectly — as regression-protected skills. One eval artifact (the verdict log) does ship to projects.

---

## 2. How consuming projects inherit the framework

Understanding the delivery vehicle is what makes this proposal framework-level rather than project-level:

| Channel | Mechanism | What travels | Update cadence |
|---|---|---|---|
| `.claude/` sync | [setup.sh:29-42](../setup.sh#L29-L42) rsync (`--delete`, excludes `session.yaml`) | Skills, **hooks**, **settings.json** (incl. permission deny rules + hook wiring), agents (role write-scopes), governance | Every `setup.sh` run — framework-owned, safe to overwrite |
| Project scaffold | setup.sh Phase 2 (init only) | `CLAUDE.md`, `.specify/` memory scaffold, `specs/`, `history/` | Once; then prompted updates |
| Interview | `sk.init` | `project-config.md`, populated memory files | On demand |

Consequences:

- **Hooks are the highest-leverage placement** for policies and guardrails: they are deterministic, cost zero tokens, run on every tool call in every consuming project, and update centrally.
- **Governance markdown** (`quality-gates.md`, `checkpoint-rules.md`) also ships — but it is only as good as the LLM that reads it, and today it references retired file layouts (§4, D3).
- **A broken hook ships too.** The four defects below are currently being distributed to every consuming project. Repairing them is the single highest-ROI action in this report.

---

## 3. Findings — current-state inventory

Legend: **DET** = deterministic (bash/config, zero tokens) · **LLM** = LLM-judged (prose rules, costs tokens, non-reproducible) · Beneficiary: **A** = framework authors, **P** = consuming projects.

### 3.1 Guardrails (prevent bad actions)

| Mechanism | Where | Type | Beneficiary | Status |
|---|---|---|---|---|
| Delete interception → archive workflow | [intercept-delete.sh](../.claude/hooks/intercept-delete.sh) (PreToolUse Bash, exit 2); redirects to `archive-file.sh` + `.archive/ARCHIVE_LOG.md` human review | DET | A + P | **Working** |
| Permission deny list (`rm`, `rmdir`, `del`, `unlink`, `Remove-Item`, piped/chained `rm`) | [settings.json:49-58](../.claude/settings.json#L49-L58) | DET | A + P | **Working** (defense-in-depth with the hook) |
| Path validation: traversal, system dirs, outside-project-root | [validate-path.sh](../.claude/hooks/validate-path.sh) (PreToolUse Edit\|Write, exit 2) | DET | A + P | **Working** |
| Per-role write scopes (`write_scope.deny` globs per role) | 6 of the 8 role files in [.claude/agents/](../.claude/agents/), enforced by validate-path.sh via `session.yaml` role | DET | P | **Partial** — `backend-qa.md` and `frontend-qa.md` declare no `write_scope` at all, so those two valid session roles are unenforced (validate-path.sh loads an empty deny list and allows everything) |
| Bypass-permissions disabled | [settings.json:129](../.claude/settings.json#L129) `disableBypassPermissionsMode: "disable"` | DET | A + P | **Working** |
| System-prompt staleness warning | [check-system-prompt-files.sh](../.claude/hooks/check-system-prompt-files.sh) (PostToolUse, advisory, always exit 0) | DET | A + P | **Working** (advisory only) |
| Human-approval checkpoints (`autopilot` \| `confirm` \| `validate`) | [checkpoint-rules.md](../.claude/skills/governance/checkpoint-rules.md); classified by sk.specify, honored by orchestrator prompts | LLM | P | **Working**, but classification and honoring are both prose |
| Loop limits (sk.clarify ≤ 3, sk.architect-probe ≤ 2) | sk.story orchestrator prompt only | LLM | P | **Prose-only** — nothing counts iterations |
| PII deny-list (observability), comment-marker greppability ("CI-greppable") | observability skills; [backend-architecture SKILL.md](../.claude/skills/backend-architecture/SKILL.md) §7 | LLM | P | **Prose-only** — no grep script or scanner exists anywhere |
| Secrets protection | Only as a *checklist item* (`Secrets scan: CLEAN`, [quality-gates.md:57](../.claude/skills/governance/quality-gates.md#L57)) | LLM | P | **Missing** as a guardrail — nothing scans writes or diffs |

### 3.2 Policies (state machine + declared conditions)

| Mechanism | Where | Type | Beneficiary | Status |
|---|---|---|---|---|
| Declarative skill preconditions (`story.<path> ==/!= value`, `file_exists: <glob>`) | `preconditions:` YAML in SKILL.md, enforced by [check-skill-preconditions.sh](../.claude/hooks/check-skill-preconditions.sh) (PreToolUse Skill, exit 2). Users: sk.ship (`verify-status == PASS`, `test-status == pass`, `security-status != BLOCKED`), sk.rollback, sk.migrate | DET | A + P | **Broken** — defects D1 + D4 below. (Note: this repo wires and runs the same hooks on itself via its own `settings.json` + `session.yaml`, so the policy tier also governs framework-side sessions — both beneficiaries inherit the breakage and the repair.) |
| Story-status state machine (frontmatter `status`, advanced per skill) | [post-skill.sh](../.claude/hooks/post-skill.sh) (unconditional: specify→draft, plan→ready, implement→testing, ship→shipped) + [post-response.sh](../.claude/hooks/post-response.sh) (conditional via `SK_RESULT` sentinel: test→review, review→verify, verify→done) | DET | P | **Broken** — defects D1 + D2 |
| `SK_RESULT: PASS|FAIL` verdict channel | Emitted by sk.test/sk.review/sk.verify prompts; parsed at [post-response.sh:81-87](../.claude/hooks/post-response.sh#L81-L87); upserts `test-status`/`verify-status` frontmatter ([post-response.sh:121-138](../.claude/hooks/post-response.sh#L121-L138)) | DET (transport) / LLM (verdict) | P | **Working in design, broken in delivery** (D1 stops the write) |
| Quality gates (6 gates, 41 checklist items) | [quality-gates.md](../.claude/skills/governance/quality-gates.md), consumed only by sk.verify as prose | LLM | P | **Degraded** — references retired artifacts (D3); 100 % LLM-judged even for mechanical items |
| Checkpoint-mode policy | [checkpoint-rules.md](../.claude/skills/governance/checkpoint-rules.md) | LLM | P | **Degraded** — references `state.yaml` (retired) |

### 3.3 Evals (measure output quality)

| Mechanism | Where | Type | Beneficiary | Status |
|---|---|---|---|---|
| `rubric:` frontmatter blocks (`name` + `checks[]` of natural-language assertions) | Exactly 3 of 25+ sk.* skills: sk.story `story-completeness`, sk.test `test-coverage`, sk.security-audit `security-coverage` | LLM | P | **Partial** — no mechanical consumer, no scoring, no record of outcomes |
| sk.verify final gate | [sk.verify/prompt.md](../.claude/skills/sk.verify/prompt.md) — evaluates gates + the 3 rubrics, emits `SK_RESULT` | LLM | P | **Working** as a judgment, but unreproducible, uncalibrated, and spends tokens on mechanical checks |
| sk.story tri-state validation gate (✅/⚠️/❌, clarify/probe loops) | sk.story orchestrator prompt | LLM | P | **Working**, human-overridable, unrecorded |
| Cache telemetry (hit-rate per skill/role) | [log-cache-metrics.sh](../.claude/hooks/log-cache-metrics.sh) → `.claude/cache-metrics.jsonl` → [cache-metrics-report.sh](../.claude/hooks/cache-metrics-report.sh) | DET | A | **Working** — the only self-measurement, and it measures token economics, not quality. Its JSONL-sink + aggregator pattern is the proven template for everything in §5.4 |
| Framework self-evals (prompt regression, fixture runs, golden scenarios) | — | — | A | **Absent.** Editing any skill's prompt.md has zero regression detection. Templates in `templates/artifacts/` are authored FROM, never validated AGAINST. NetArchTest invariants (backend-architecture §8) execute only inside generated target projects — nothing here exercises them |
| Verdict tracking / judge calibration | — | — | A + P | **Absent.** PASS/FAIL verdicts vanish into the transcript; no rate, no drift signal |

---

## 4. Verified defects (evidence-checked, file:line)

These six defects are why "repair before extend" is the verdict. All were verified by direct file reads (and, for D4, an empirical bash reproduction) on 2026-07-13.

**D1 — Stale story glob: the state machine points at a retired layout.**
All three state-machine hooks locate the story via
`specs/intents/*/units/*/stories/story-{ID}.md`
— [check-skill-preconditions.sh:58](../.claude/hooks/check-skill-preconditions.sh#L58), [post-response.sh:105](../.claude/hooks/post-response.sh#L105), [post-skill.sh:58](../.claude/hooks/post-skill.sh#L58) —
while current skills write `specs/intents/{intent}/units/{unit}/{NN}-story/story.md` — a zero-padded *sequence* defined by [sk.story/prompt.md:28-36](../.claude/skills/sk.story/prompt.md#L28-L36) (`01-story`, `02-story`, …), of which downstream prompts (sk.implement, sk.test, sk.security-audit) currently hardcode only the first.
**Consequence chain:** status transitions no-op (their stderr warnings surface nowhere) → `test-status`/`verify-status` are never upserted → and because the precondition hook **fails closed** when a `story.*` rule is present but no story file is found ([check-skill-preconditions.sh:141-145](../.claude/hooks/check-skill-preconditions.sh#L141-L145)), **sk.ship is permanently blocked** for any story in the current layout. The framework's flagship deterministic gate can currently only say "no."

**D2 — Status write corrupts nested YAML + writes out-of-enum values.**
[story-template.md:6-8](../templates/artifacts/story-template.md#L6-L8) defines `status:` as a **nested map** (`current` / `entered_at` / …) with enum `draft | ready | in-progress | review | review-rejected | testing | security-review | done`. But both hooks write with
`sed "s/^status:.*$/status: ${NEW_STATUS}/"`
([post-skill.sh:77](../.claude/hooks/post-skill.sh#L77), [post-response.sh:150](../.claude/hooks/post-response.sh#L150)) — flattening the parent key and orphaning the indented children: invalid frontmatter after the first transition. Additionally, the hooks write statuses that are **not in the template enum**: `verify` (sk.review PASS, [post-response.sh:52](../.claude/hooks/post-response.sh#L52)) and `shipped` (sk.ship, [post-skill.sh:37](../.claude/hooks/post-skill.sh#L37)). There is no single source of truth for the status vocabulary.

**D3 — Governance and agent documents reference retired artifacts.**
[quality-gates.md](../.claude/skills/governance/quality-gates.md) references `.specify/intents/` (line 9), `state.yaml` (lines 10, 19 — now `session.yaml`), `tasks.yaml` (line 32 — sk.plan produces `tasks.md`), and `security-audit.md` (line 53 — now `07-security-audit/` with four files). [checkpoint-rules.md:2-6](../.claude/skills/governance/checkpoint-rules.md#L2-L6) references `state.yaml` twice. [po.md:40](../.claude/agents/po.md#L40) still documents the retired `stories/story-{ID}.md` layout. sk.verify LLM-judges against files that cannot exist — silently degrading verdict quality: the judge either hallucinates equivalence or fails items for the wrong reason.

**D4 — `file_exists` preconditions are a dead check on paths containing spaces (fail-open).**
[check-skill-preconditions.sh:124](../.claude/hooks/check-skill-preconditions.sh#L124) expands the glob **unquoted**:
`MATCHES=( ${PROJECT_ROOT}/${GLOB} )`
A project root containing a space (this very repo: `d:\work\SDD Reference\...`) word-splits — and the first token (`/d/work/SDD`) contains no glob metacharacters, so `nullglob` does **not** remove it. `MATCHES` always ends up non-empty, the emptiness test at line 126 never fires, and the precondition **always passes — even when the required file is missing** (empirically reproduced). This is a silent policy hole, not a false block: sk.migrate's `file_exists: …/data-model.md` gate cannot block anything on a spaced root. (Correct form: `MATCHES=( "${PROJECT_ROOT}"/${GLOB} )` — quote the root, leave the glob unquoted.)

**D5 — Sub-skill invocation names bypass the status map (confirmed).**
[post-skill.sh:34](../.claude/hooks/post-skill.sh#L34) maps `sk.specify → draft`, but the orchestrator invokes the sub-skill as `sk.story/sk.specify` ([sk.story/prompt.md:54](../.claude/skills/sk.story/prompt.md#L54); likewise `sk.story/sk.clarify`, `sk.story/sk.architect-probe`). The nested name passes the hook's `sk.*` prefix guard but never matches the exact-match `case` — it falls through to `*) exit 0`. The `sk.specify → draft` transition is dead code. Same drift class as D1: align the map on basename or full nested name consistently.

**D6 — QA roles have no write-scope enforcement.**
`backend-qa.md` and `frontend-qa.md` in [.claude/agents/](../.claude/agents/) declare no `write_scope` block (the other 6 role files do). Both are valid session roles, so validate-path.sh loads an empty deny list for them and allows every write. A guardrail documented as role-based is silently absent for two roles.

---

## 5. Proposals — form & shape

Design rule for everything below: **ride the seams that already exist** — exit-code-2 PreToolUse blocking, the `SK_RESULT` sentinel → frontmatter propagation, `preconditions:`/`rubric:` frontmatter grammar, and the JSONL-sink + report-script telemetry pattern. No new runtimes, no dependencies beyond bash + jq (already required by hooks), no platform adoption.

### 5.1 Stage 0 — Repair the policy substrate *(prerequisite for everything)*

| Fix | Files | Shape |
|---|---|---|
| D1: story glob → current layout | 3 hooks | `specs/intents/*/units/*/*-story/story.md` (the `{NN}-story` folder is a *sequence*, not always `01-`); disambiguate by matching frontmatter `id:` against `active_story_id`, not by filename |
| D2a: nested-safe status write | post-skill.sh, post-response.sh | Replace `sed` with an awk upsert targeting `status.current` (mirror the read-side awk that already exists at [check-skill-preconditions.sh:70-110](../.claude/hooks/check-skill-preconditions.sh#L70-L110)) |
| D2b: one status vocabulary | template + hooks + governance | Reconcile the enum — an explicit decision: today's template enum includes `review-rejected` and lacks `verify`/`shipped`, which the hooks write; pick the final vocabulary and encode it once in `policies.yaml` (§5.3) as the SSOT both hooks and template docs point to |
| D3: governance + agent path refresh | quality-gates.md, checkpoint-rules.md, agents/po.md | `state.yaml`→`session.yaml`, `.specify/intents/`→`specs/intents/`, `tasks.yaml`→`tasks.md`, `security-audit.md`→`07-security-audit/*`, retired `stories/` layout in po.md |
| D4: quote the glob root | check-skill-preconditions.sh:124 | One-line fix + a test proving `file_exists` both passes *and blocks* correctly on a path with a space |
| D5: sub-skill name alignment | post-skill.sh | Match on basename or full nested name consistently (`sk.story/sk.specify` currently falls through the exact-match `case`) |
| D6: QA role write scopes | agents/backend-qa.md, agents/frontend-qa.md | Author the missing `write_scope.deny` blocks so validate-path.sh has something to enforce for QA sessions |

**Benefit:** every consuming project's ship-gate, status automation, and precondition policies start working *as already documented*. Zero new concepts. This is repair, not construction — but without it, Stages 1–4 automate a fiction.

### 5.2 Stage 1 — Framework lint + verdict log *(protects the framework's own evolution)*

**(a) `scripts/lint-framework.sh`** — a deterministic, zero-token structural linter for the framework itself (~200 lines bash; dev-time, run manually or as an advisory hook):

- every `sk.*` folder (including nested sub-skills) has `SKILL.md` + `prompt.md`; frontmatter `name:` matches folder
- every `inject_files:` entry resolves to an existing file — **the direct regression guard for the in-flight prompt-cache refactor**, which is precisely a reshuffling of inject_files
- every `subagent_type:` maps to a defined agent in `.claude/agents/`
- `preconditions:` / `rubric:` / (future) `postconditions:` blocks parse against the supported grammar — today a typo'd rule produces only a runtime stderr warning nobody sees ([check-skill-preconditions.sh:165](../.claude/hooks/check-skill-preconditions.sh#L165))
- `settings.json` hook commands point at existing executable files
- **legacy-token tripwire:** grep skills/hooks/governance **and `.claude/agents/`** for banned tokens (`state.yaml`, `stories/story-`, retired skill names) so drift of the D1/D3 class can never silently recur
- exit 1 on any failure with `file:line — rule N` output

Wire a thin **advisory** PostToolUse hook (clone of check-system-prompt-files.sh — warn, never block) that runs the lint whenever `.claude/skills/**` is edited.

**(b) Verdict log** — ~15 lines added to post-response.sh: whenever it parses `SK_RESULT`, append `{ts, skill, story, verdict, prompt_sha}` to `.claude/verdict-log.jsonl` (`prompt_sha` = git blob hash of the skill's prompt.md). Ships to projects via the normal `.claude/` sync; costs zero tokens; over weeks yields PASS/FAIL rates per skill per prompt version — the raw material for judge calibration, without building any calibration machinery now.

### 5.3 Stage 2 — Policies-as-code *(turn the mechanical 40 % of the quality gate deterministic)*

**(a) `governance/policies.yaml`** — one declarative file, next to quality-gates.md, holding per-artifact structural contracts:

```yaml
status_enum: [draft, ready, in-progress, review, review-rejected, testing, security-review, verify, shipped, done]
#   ^ illustrative — the final vocabulary is the D2b reconciliation decision (Stage 0); this file is its single definition site
artifacts:
  story:
    path: "specs/intents/*/units/*/01-story/story.md"
    frontmatter:
      required: [id, status.current, test-status?, verify-status?, security-status?]
      enums: { status.current: $status_enum, test-status: [pass, fail], ... }
    sections:
      required: ["Acceptance Criteria"]   # non-empty
  plan:
    path: "specs/intents/*/units/*/03-plan/*/plan.md"
    ...
```

**(b) `scripts/validate-artifacts.sh`** — reads policies.yaml, validates any artifact (or all artifacts of the active story), plain-text pass/fail per rule. Bash + awk, no new dependencies.

**(c) Re-tag [quality-gates.md](../.claude/skills/governance/quality-gates.md) items `[auto]` / `[judge]`.** Line-by-line classification of the 41 items across 6 gates: **~16 (≈40 %) are fully mechanizable** (existence, session-field, enum, and count checks — e.g. "plan.md exists", "checkpoint mode set", "all OWASP items documented as PASS/FAIL/NA", "verdict: CLEAR or CONDITIONAL", "all tasks have status done"), **~11 more are partially mechanizable** (structure auto, adequacy judged — e.g. "acceptance criteria exist *and are testable*"), and **~14 stay judgment** ("no undefined external dependencies", "no dual-write"). sk.verify's prompt is amended to run `validate-artifacts.sh` via Bash **first**, then spend judgment tokens only on `[judge]` items. The gate becomes cheaper, faster, and 40 % reproducible.

**(d) `postconditions:` frontmatter block** — sibling of `preconditions:`, e.g. for sk.plan: `artifact_exists: specs/intents/*/units/*/03-plan/*/plan.md`. Enforced at the **Stop hook** (artifacts exist only after the response completes): post-skill.sh records each sk.* invocation to a marker; the Stop hook evaluates the declared postconditions + the artifact contract, and on failure **exits 2** — feeding the failure text back to the agent, which self-corrects mid-session ("sk.plan completed but 03-plan/{Project}/plan.md missing"). The existing `stop_hook_active` recursion guard ([post-response.sh:28-31](../.claude/hooks/post-response.sh#L28-L31)) already prevents loops.

### 5.4 Stage 3 — Eval harness *(dev-time; the missing regression safety net)*

A new top-level `evals/` directory — nothing in `.claude/` depends on it; the framework stays fully usable without it; it is **not** synced to consuming projects:

```
evals/
  fixtures/payments-demo/     # ONE frozen miniature project: intent, unit, unit-brief,
                              #   session.yaml, minimal .specify/memory/* (the real authoring work)
  scenarios/
    story-capture.yaml        # skill: sk.story  | scripted inputs | rubric: story-completeness
    verify-gate.yaml          # skill: sk.verify | fixture with SEEDED DEFECTS | expected: FAIL
    plan-unit.yaml            # skill: sk.plan   | structural policy score only
  run-eval.sh                 # copy fixture → temp workdir → headless `claude -p` skill run
                              #   → capture artifacts + transcript
  judge-rubric.sh             # ONE `claude -p` call: renders the skill's existing rubric: block
                              #   as a scoring prompt, demands strict JSON {check, pass, evidence}
  eval-metrics.jsonl          # {ts, scenario, skill, prompt_sha, structural_score, rubric_score, per_check[]}
  eval-report.sh              # jq aggregator (summary | tail | since) — clone of cache-metrics-report.sh
```

Design decisions:

- **Two-stage scoring**: stage 1 is free — `validate-artifacts.sh` (§5.3b, reused) scores structure; stage 2 is a single LLM-judge call per scenario using the `rubric:` blocks the skills already declare. The rubrics finally get a mechanical consumer.
- **Keyed by `prompt_sha`** — the regression question becomes a diff: run before a prompt edit, run after, compare rows. This is exactly the safety net the P1–P10 cache refactor lacks.
- **One inverted scenario** (seeded defects, expected `FAIL`) so *judge drift toward leniency* is caught, not just capability regression.
- **Cost envelope**: a full run ≈ 3 skill executions + 3 judge calls ≈ **$1–5**; run at human-chosen checkpoints (before/after prompt edits), never in CI, never per-commit.

### 5.5 Stage 4 — Guardrail extensions for consuming projects *(prioritized backlog, build on demand)*

Ranked; each ships automatically via the `.claude/` sync once built:

1. **Secrets guard** (highest value): PreToolUse Edit|Write hook matching common credential patterns (private keys, `AKIA…`, connection strings with passwords, JWT literals) — turns the `Secrets scan: CLEAN` checklist *item* into an actual guardrail. Advisory first, blocking after a false-positive burn-in.
2. **Comment-marker verifier**: `scripts/check-markers.sh` shipped to projects — makes backend-architecture §7's "CI-greppable" claim real (`// ENDPOINT:`, `// AUTH:`, `// OUTBOX:`… present where policies.yaml says they must be). Also usable as a `[auto]` quality-gate item.
3. **Mechanical loop limits**: clarify/probe iteration counters persisted in the story folder; precondition-style check blocks the 4th sk.clarify. Removes reliance on the orchestrator prompt remembering its own limit.
4. **Rubric blocks for all sk.\* skills** (currently 3 of 25+): cheap to author, immediately consumable by sk.verify and the eval harness.
5. **CI recipe (optional, docs-only)**: a sample GitHub Actions snippet consuming `lint-framework.sh` + `validate-artifacts.sh` for projects that want gate enforcement outside the agent session. Deterministic scripts only — never LLM evals in CI.

---

## 6. Benefits & impact

| Proposal | Failure mode it eliminates | Build effort | Run cost | Workflow change | Beneficiary |
|---|---|---|---|---|---|
| Stage 0 — repair | Ship-gate permanently blocked; status automation dead; YAML corruption on first transition; `file_exists` gate that can never block; unenforced QA roles; judge grading against phantom files | 0.5–1 day | zero | None — documented behavior starts being true | **A + P** (every project, immediately on next setup.sh; this repo runs the same hooks on itself) |
| Stage 1a — framework lint | Broken inject_files / dangling subagent_type / typo'd grammar after skill edits; recurrence of D1/D3-class drift | 1 day | zero | One command around skill edits; advisory warning on save | **A** (protects the product all P's consume) |
| Stage 1b — verdict log | Judge drift invisible; no PASS/FAIL history | 2 h | zero | None | A + P |
| Stage 2 — policies-as-code | Malformed artifacts entering the pipeline; skills "completing" without producing outputs; sk.verify burning tokens on mechanical checks | 2–3 days | zero (and *reduces* sk.verify tokens ~40 %) | Invisible until violated; then the agent self-corrects mid-session | **P** |
| Stage 3 — eval harness | Prompt edit silently degrades skill output or judge leniency | 2–4 days (fixture is most of it) | $1–5 per full run, on demand | Framework author runs it around prompt edits | **A** (indirectly every P) |
| Stage 4 — guardrail backlog | Committed secrets; unbounded clarify loops; unverifiable marker discipline | ½–1 day each | zero | None (hooks) | **P** |

**The compound effect for a consuming project** — what "using this framework" means after Stages 0–2, at zero token overhead:

- a story **cannot ship** unless verify/test/security fields say so, and those fields are **actually written** by working hooks;
- every artifact the pipeline produces is **structurally valid by construction** (self-healing postconditions);
- the expensive LLM gate spends judgment **only where judgment is needed**;
- dangerous actions (delete, path escape, role overreach, committed secrets) are **physically blocked**, not discouraged;
- and the skills themselves come from a framework whose every prompt change was **regression-checked against golden fixtures** before release.

---

## 7. Staged implementation plan

| Stage | Scope | Effort | Depends on | Acceptance criteria |
|---|---|---|---|---|
| **0 — Repair** | Fix D1–D6: globs, nested status upsert, enum SSOT decision, governance/agent paths, quoted glob root, sub-skill name map, QA write scopes | 0.5–1 d | — | A story created under the `{NN}-story/` layout transitions `draft→…→done` end-to-end via hooks on a scratch fixture; sk.ship precondition passes/blocks correctly on both PASS and FAIL fixtures; frontmatter stays valid YAML after every transition; on a repo path containing a space, `file_exists` both passes when the file exists *and blocks when it doesn't*; a QA-role session is denied an out-of-scope write |
| **1 — Lint + verdict log** | `scripts/lint-framework.sh` (7 rule families + tripwire), advisory hook wiring, verdict-log append in post-response.sh | 1 d (+2 h) | Stage 0 (tripwire token list comes from the repair) | Lint runs clean on the repo; seeding any single defect class (dangling inject_files, bad grammar, legacy token) is caught with file:line; a verify run appends one well-formed JSONL row |
| **2 — Policies-as-code** | `governance/policies.yaml`, `scripts/validate-artifacts.sh`, `[auto]`/`[judge]` tagging of all 41 gate items, sk.verify prompt integration, `postconditions:` grammar + Stop-hook enforcement | 2–3 d | Stage 0 | All `[auto]` items produce identical results on repeated runs; sk.verify's transcript shows script-first evaluation; deleting a required artifact after a skill run triggers exit-2 self-heal feedback; status enum has exactly one definition site |
| **3 — Eval harness** | `evals/` dir: 1 fixture, 3 scenarios (incl. the inverted FAIL case), run/judge/report scripts, baseline capture | 2–4 d | Stage 0; reuses Stage 2 scorer (structural stage degrades gracefully to rubric-only if built first) | Two consecutive runs on unchanged prompts produce scores within noise; the seeded-defect scenario returns FAIL; a deliberate prompt regression (remove a rubric-relevant instruction) moves the score; **baseline row captured before the next prompt-cache refactor phase** |
| **4 — Guardrail backlog** | Secrets guard → marker verifier → loop counters → rubric completion → CI recipe, in that order, as capacity allows | ½–1 d each | Stages 0–2 | Each: demonstrably blocks/flags its seeded violation; false-positive rate acceptable after burn-in (secrets guard ships advisory-first) |

**Sequencing rationale:** Stage 0 unblocks everything and is pure repair. Stage 1 is the cheapest insurance and is time-sensitive — it structurally protects the in-flight prompt-cache refactor. Stage 2 converts existing prose policy into enforcement. Stage 3 adds the genuinely new capability (measurement). Stage 4 is a backlog, not a phase — pull items when a concrete need appears. If the cache-refactor timeline is tight: do Stages 0+1 in one sitting, resume the refactor under lint protection, then schedule 2 and 3.

---

## 8. What NOT to build (over-engineering traps at this weight class)

- **No eval platform** (promptfoo, LangSmith, Braintrust): 3–5 scenarios in a bash-and-markdown framework don't justify a dependency stack, an account, or a schema migration.
- **No per-commit LLM evals in CI**: cost × nondeterminism = noise. LLM evals run at human-chosen checkpoints. (Deterministic lint in CI is fine — Stage 4, optional.)
- **No statistical rigor theater**: n = 1–2 per scenario; treat evals as smoke tests with score deltas, not benchmarks with confidence intervals.
- **No JSON Schema tooling for markdown artifacts**: required-frontmatter/required-sections in one YAML file is proportionate; a schema-validator dependency is ceremony.
- **No runtime LLM judging beyond sk.verify**: the framework already has exactly one runtime judge; the eval judge stays dev-side. Per-run double-judging doubles token cost for marginal signal.
- **No dashboards, no auto-repair bots, no multi-model judge panels, no eval-driven prompt auto-tuning.** Revisit only when the framework has enough consuming projects that verdict-log data shows a real calibration problem.

---

## 9. Appendix — evidence table

| # | Claim | Evidence |
|---|---|---|
| 1 | `.claude/` (hooks, settings, skills, governance) rsyncs to consuming projects on every setup | [setup.sh:29-42](../setup.sh#L29-L42) |
| 2 | Stale story glob in all three state-machine hooks | [check-skill-preconditions.sh:58](../.claude/hooks/check-skill-preconditions.sh#L58), [post-response.sh:105](../.claude/hooks/post-response.sh#L105), [post-skill.sh:58](../.claude/hooks/post-skill.sh#L58) |
| 3 | Precondition hook fails closed when story.* rule present but story not found | [check-skill-preconditions.sh:141-145](../.claude/hooks/check-skill-preconditions.sh#L141-L145) |
| 4 | Flattening `sed` on nested `status:` map | [post-skill.sh:77](../.claude/hooks/post-skill.sh#L77), [post-response.sh:150](../.claude/hooks/post-response.sh#L150) vs [story-template.md:6-8](../templates/artifacts/story-template.md#L6-L8) |
| 5 | Out-of-enum statuses written by hooks (`verify`, `shipped`) | [post-response.sh:52](../.claude/hooks/post-response.sh#L52), [post-skill.sh:37](../.claude/hooks/post-skill.sh#L37) vs enum at [story-template.md:7](../templates/artifacts/story-template.md#L7) |
| 6 | Governance references retired artifacts (`state.yaml`, `.specify/intents/`, `tasks.yaml`, `security-audit.md`) | [quality-gates.md:9-10,19,32,53](../.claude/skills/governance/quality-gates.md#L9), [checkpoint-rules.md:2-6](../.claude/skills/governance/checkpoint-rules.md#L2-L6) |
| 7 | Unquoted glob expansion makes `file_exists` fail-open (always passes) on paths with spaces — empirically reproduced | [check-skill-preconditions.sh:124-126](../.claude/hooks/check-skill-preconditions.sh#L124-L126) |
| 8 | `SK_RESULT` sentinel parse + frontmatter upsert + recursion guard | [post-response.sh:81-87](../.claude/hooks/post-response.sh#L81-L87), [:121-138](../.claude/hooks/post-response.sh#L121-L138), [:28-31](../.claude/hooks/post-response.sh#L28-L31) |
| 9 | Precondition grammar + silent unknown-rule warning | [check-skill-preconditions.sh:36-44](../.claude/hooks/check-skill-preconditions.sh#L36-L44), [:165](../.claude/hooks/check-skill-preconditions.sh#L165) |
| 10 | Quality gates: 6 gates, 41 items, LLM-consumed only by sk.verify | [quality-gates.md](../.claude/skills/governance/quality-gates.md) (items: Spec 4, Architecture 7, Plan 6, Implementation 8, Test 9, Security 7) |
| 11 | `rubric:` blocks exist in exactly 3 skills | sk.story, sk.test, sk.security-audit `SKILL.md` frontmatter |
| 12 | Delete guardrails: hook + settings deny + archive workflow | [intercept-delete.sh](../.claude/hooks/intercept-delete.sh), [settings.json:49-58](../.claude/settings.json#L49-L58) |
| 13 | Role write-scopes present in 6 of 8 role agents; absent from `backend-qa.md` and `frontend-qa.md` | `write_scope.deny` in [.claude/agents/](../.claude/agents/)`{architect,backend-engineer,frontend-engineer,lead,po,security}.md`; zero occurrences in the two QA role files |
| 14 | Cache telemetry is the only framework self-measurement | [log-cache-metrics.sh](../.claude/hooks/log-cache-metrics.sh), [cache-metrics-report.sh](../.claude/hooks/cache-metrics-report.sh) |
| 15 | Sub-skill status-map mismatch (confirmed) — `sk.specify → draft` is dead code | [post-skill.sh:33-39](../.claude/hooks/post-skill.sh#L33-L39) exact-match `case` vs nested invocation at [sk.story/prompt.md:54](../.claude/skills/sk.story/prompt.md#L54) (`sk.story/sk.specify`; likewise sk.clarify:83, sk.architect-probe:113) |
| 16 | `{NN}-story/` is a zero-padded sequence (not always `01-`) | [sk.story/prompt.md:28-36](../.claude/skills/sk.story/prompt.md#L28-L36); sk.implement/sk.test/sk.security-audit prompts hardcode `01-story` |
| 17 | Stale `stories/story-{ID}.md` layout also survives in an agent file | [po.md:40](../.claude/agents/po.md#L40) |

---

*Review note: an independent adversarial verification pass (fresh-context agent, 2026-07-13) re-checked every factual claim against the repo — ~38 claims confirmed by direct file reads, one by empirical bash reproduction. It corrected three findings that are now incorporated: D4's consequence was inverted (fail-open, not fail-closed), the role write-scope coverage was 6 of 8 (not 7 of 7 — now defect D6), and the story-folder layout is a `{NN}-story` sequence (repair glob adjusted). It also upgraded D5 from suspected to confirmed and validated the coverage matrix (3 pillars × 2 beneficiaries × {findings, proposals, benefits, staged plan}) as complete.*
