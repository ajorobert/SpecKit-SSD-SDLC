# Report: Separating Framework Skills from Project Skills via a Plugin-Marketplace Skills Repository

**Date:** 2026-08-23
**Status:** Proposal / migration roadmap
**Scope:** SpecKit-SSD-SDLC framework repo + consuming projects
**Reference:** Anthropic docs — *"Set up a skills repository Claude can update"* (Claude Code plugin-marketplace layout, auto-sync, Claude-authored skill PRs)

---

## 1. Executive Summary

Today the framework repo ships **two fundamentally different kinds of skills in one folder** (`.claude/skills/`), distributed together via git subtree + `setup.sh` rsync:

1. **Framework skills** — the 23 `sk.*` pipeline skills + `governance/`. Stack-agnostic SDLC machinery. These belong to the framework and should be overwritten on every framework update.
2. **Tech-stack pattern skills** — ~24 skills (`backend-architecture`, `nextjs-patterns`, `data-access-patterns`, …) that encode *one project's chosen stack* (.NET 10 seam architecture, FastEndpoints, Next.js portal, React Native mobile). These are **project assets wearing framework clothing**.

The proposal: move the tech-stack pattern skills into a **separate, project-owned git repository laid out as a Claude Code plugin marketplace** (`.claude-plugin/marketplace.json` + one folder per plugin). This unlocks the new Claude platform capabilities described in the attached article:

- **Auto-sync**: register the repo as a plugin marketplace; on merge to the default branch, every scope/channel/session picks up the update — no `setup.sh` re-run.
- **Claude-updatable skills**: grant Claude write access and it can open PRs against the skills repo from what it learns during real work; a human reviews and merges.
- **Multi-surface reach**: the same skills repo serves Claude Code (CLI/web), Claude Tag (Slack), and any future project on the same stack.
- **Clean framework updates**: `setup.sh`'s `rsync --delete` can keep overwriting `.claude/` safely because project skills no longer live there.

The framework's own design rule already anticipates this split — `backend-architecture §1`: *"Skills carry grammar, project memory carries vocabulary."* This proposal adds the missing third tier: **framework carries process, skills repo carries stack grammar, project memory carries vocabulary.**

---

## 2. Current State

### 2.1 Skill inventory (51 skills in `.claude/skills/`)

| Family | Count | Skills | True owner |
|---|---|---|---|
| **Pipeline (`sk.*`)** | 23 | `sk.story`, `sk.design`, `sk.plan`, `sk.implement`, `sk.test`, `sk.review`, `sk.verify`, `sk.ship`, `sk.session`, `sk.init`, `sk.adr`, `sk.phr`, `sk.impact`, `sk.investigate`, `sk.refactor`, `sk.migrate`, `sk.perf`, `sk.hotfix`, `sk.rollback`, `sk.security-audit`, `sk.uat`, `sk.knowledge-base`, `sk.ff` | **Framework** |
| **Governance** | 1 | `governance/` (checkpoint-rules.md, quality-gates.md) | **Framework** |
| **Memory loaders** | 6 | `system-context`, `service-registry`, `domain-model`, `architecture-decisions`, `standards`, `design-principles` | **Framework** (thin loaders over `.specify/memory/` — the *content* is project, the *loader* is framework) |
| **Backend stack patterns** | 12 | `backend-architecture`, `backend-feature-patterns`, `api-endpoint-patterns`, `authorization-patterns`, `orchestration-patterns`, `integration-adapter-patterns`, `feature-management-patterns`, `infrastructure-wiring`, `design-code-review`, `observability-backend`, + data quartet below | **Project / stack** |
| **Data patterns** | 4 | `data-access-patterns`, `caching-patterns`, `search-patterns`, `file-pipeline-patterns` | **Project / stack** |
| **Frontend patterns** | 9 | `nextjs-patterns`, `react-admin-patterns`, `react-native-patterns`, `frontend-design-system`, `react-component-patterns`, `zustand-state-management`, `accessibility-standards`, `observability-frontend` | **Project / stack** |

*(`design-principles` is a judgment call — it is stack-neutral DDD/DDIA guidance. Recommendation: keep it in the framework; it informs `sk.design` regardless of stack.)*

### 2.2 Distribution model today

```
Framework repo (this repo)
   └─ git subtree add --prefix=.speckit <framework-url>
        └─ bash .speckit/setup.sh
             └─ rsync -a --delete .speckit/.claude/ → project/.claude/
```

**Consequences of the current model:**

- `rsync --delete` means **any project-local skill edit is destroyed on every framework update**. Projects cannot safely evolve their own pattern skills.
- A second project on a different stack (say, Go + Vue) would inherit 24 irrelevant .NET/React skills and have to fork the framework to replace them — defeating the subtree-update story entirely.
- Skill improvements learned during real work die in the session. There is no channel for Claude to persist "that worked, remember it" back into the skills — the article's core capability.

### 2.3 Coupling points (what actually binds the two families together)

Audit of cross-references:

1. **Hardcoded path routing tables** — the biggest coupling. Nine framework prompt files route by keyword to literal paths:
   - `sk.implement/sk.codegen/prompt.md` (e.g. line 21: `Always (canonical SSOT): .claude/skills/backend-architecture/SKILL.md`)
   - `sk.implement/sk.scaffolding/prompt.md`, `sk.review/prompt.md`, `sk.design/sk.architecture/prompt.md`, `sk.design/sk.ui-design/prompt.md`, `sk.perf/prompt.md`, `sk.refactor/prompt.md`, `sk.test/sk.testproject/prompt.md`, `sk.uat/prompt.md`
2. **CLAUDE.md "Tech Stack Context Skills" tables** — the root instruction file enumerates stack skills by folder name and load conditions.
3. **`inject_files` frontmatter** — 22 skills use it; nearly all targets are `.specify/memory/*` (project memory — correct and unaffected) or `governance/*` (framework-internal — unaffected). Only one stack-skill-to-stack-skill inject exists (`data-access-patterns/SKILL.md`), which moves with its family.
4. **Placeholder convention** — already isolates project *facts* (`YourContext.*`, tenancy markers, permission catalog) into `.specify/memory/`. This is the strongest existing asset: pattern skills are stack-specific but already project-*instance*-neutral, so they can be shared by any project on the same stack.

**Good news:** coupling points 1 and 2 are the only real surgery. Point 3 needs no change; point 4 is a tailwind.

---

## 3. Target State

### 3.1 Three-tier ownership model

```
┌──────────────────────────────────────────────────────────────────┐
│ Tier 1 — FRAMEWORK repo (SpecKit-SSD-SDLC)                       │
│   Process: sk.* pipeline, governance, memory-loader skills,      │
│   agents, hooks, templates, setup.sh                             │
│   Stack-agnostic. Updated via git subtree pull.                  │
├──────────────────────────────────────────────────────────────────┤
│ Tier 2 — SKILLS repo (NEW: e.g. <org>/dotnet-react-skills)       │
│   Stack grammar: the 24 pattern skills, bundled as plugins in a  │
│   Claude Code plugin-marketplace layout.                         │
│   Private/internal GitHub repo. Auto-syncs to claude.ai;         │
│   pinned as a marketplace in each project's .claude/settings.json│
│   Claude opens PRs against it. Humans merge.                     │
├──────────────────────────────────────────────────────────────────┤
│ Tier 3 — PROJECT repo                                            │
│   Vocabulary: .specify/memory/ (system-context, standards,       │
│   auth_contract, observability-stack), specs/, knowledge bases,  │
│   session.yaml, and the settings.json that pins Tier 2.          │
└──────────────────────────────────────────────────────────────────┘
```

Each tier changes at its own cadence: framework rarely, skills repo when the team learns something, project memory continuously.

### 3.2 Skills repository layout (per the article + Claude Code plugin spec)

```
dotnet-react-skills/                        # private GitHub repo
├── .claude-plugin/
│   └── marketplace.json                    # lists each plugin
├── backend-dotnet/                         # plugin 1
│   ├── .claude-plugin/plugin.json
│   └── skills/
│       ├── backend-architecture/SKILL.md   # canonical SSOT — moves intact
│       ├── backend-feature-patterns/SKILL.md
│       ├── api-endpoint-patterns/SKILL.md
│       ├── authorization-patterns/SKILL.md
│       ├── orchestration-patterns/SKILL.md
│       ├── integration-adapter-patterns/SKILL.md
│       ├── feature-management-patterns/SKILL.md
│       ├── infrastructure-wiring/SKILL.md
│       ├── design-code-review/SKILL.md
│       └── observability-backend/SKILL.md
├── data-dotnet/                            # plugin 2
│   └── skills/ … data-access, caching, search, file-pipeline
├── frontend-web/                           # plugin 3
│   └── skills/ … nextjs, react-admin, design-system,
│                 react-component, zustand, accessibility,
│                 observability-frontend
└── frontend-mobile/                        # plugin 4
    └── skills/ … react-native-patterns
```

`marketplace.json` (shape per Claude Code plugin-marketplace spec — verify field names against current docs at implementation time):

```json
{
  "name": "dotnet-react-skills",
  "owner": { "name": "Your Org" },
  "plugins": [
    { "name": "backend-dotnet",  "source": "./backend-dotnet",  "description": ".NET 10 seam-architecture backend patterns" },
    { "name": "data-dotnet",     "source": "./data-dotnet",     "description": "PostgreSQL/EF/Dapper, HybridCache, Elasticsearch, SeaweedFS" },
    { "name": "frontend-web",    "source": "./frontend-web",    "description": "Next.js portal + React admin SPA patterns" },
    { "name": "frontend-mobile", "source": "./frontend-mobile", "description": "React Native / Expo patterns" }
  ]
}
```

**Why four plugins, not one or twenty-four:** plugins are the enable/disable unit per scope. A backend-only service repo enables `backend-dotnet` + `data-dotnet` and never loads frontend skills; the mobile team's channel enables `frontend-mobile`. One-plugin-per-skill would make scope admin tedious; one giant plugin loses the selectivity. The four bundles mirror the existing CLAUDE.md table sections (Backend / Data / Frontend-Portal+Admin / Mobile).

**What does NOT move:** `.specify/memory/*` stays in each project (it is per-project vocabulary — schema names, tenancy markers, permission catalog). The `inject_files` pointers from pattern skills to `.specify/memory/*` are *relative to the consuming project root* and keep working, because plugin skills execute in the project's working directory.

### 3.3 How skills resolve after the split

- Plugin skills surface to Claude as `plugin-name:skill-name` (e.g. `backend-dotnet:backend-architecture`), but the skill's own `name:` frontmatter stays unchanged, so descriptions and trigger phrases are untouched.
- Framework routing tables switch from **paths to names** (see §5, Phase 2) — the Skill tool resolves a named skill regardless of whether it came from `.claude/skills/`, a plugin, or claude.ai sync. This single change makes the framework stack-agnostic: a Go project supplies a marketplace whose plugins expose *differently named* skills via a project-owned routing manifest.

---

## 4. New Claude Capabilities This Unlocks

| Capability | What it gives you | Requirement |
|---|---|---|
| **Marketplace auto-sync** (claude.ai) | Merge to default branch → plugins re-sync org-wide → next thread/session uses the update. Replaces `setup.sh` re-runs for skills. | Private/internal GitHub repo; GitHub connector enabled; *Admin settings → Plugins → Add plugins → Sync from GitHub*, leave **Sync automatically** on |
| **Claude-authored skill PRs** | "@Claude that worked — open a PR to the skills repo so `caching-patterns` covers that invalidation edge case." Claude opens the PR under the Claude GitHub App identity, linked to the thread. You review/merge like any contributor. | Access bundle → *Repositories* tab → add the skills repo (write). Claude GitHub App linked to the org |
| **Scoped attachment** | Different bundles/channels/projects enable different plugin subsets from the same repo. | Bundle → *Plugins* tab → toggle per plugin |
| **Routine-driven improvement loop** | "Every Friday, review what you got wrong this week and open one PR to the skills repo with the fixes." Corrections stop evaporating. | A routine in the channel, or a scheduled Claude Code session |
| **Team-wide auto-install in Claude Code** | Check a marketplace pin + enabled plugins into the project's `.claude/settings.json`; every teammate and every claude.ai/code web session gets the skills without any setup step. | Claude Code plugin marketplace support (`/plugin marketplace add`, `extraKnownMarketplaces` / `enabledPlugins` in settings) |
| **Skill tooling** | `skill-creator` to author/refine skills; plugin eval / skill-doctor to test that skills trigger when they should — CI for the skills repo. | Claude Code CLI |
| **Human-gated change control** | Every skill change is a PR + merge. The framework's `.archive/` + no-delete policy is complemented by git history in the skills repo. | Nothing extra — inherent to the repo pattern |

**The improvement loop, end to end:**

```
Claude works in a session/channel (skills v1)
   → learns a correction ("Dapper read model needed PIT pagination here")
   → prompted (or routine-swept): opens PR against dotnet-react-skills
   → human reviews the diff to search-patterns/SKILL.md, merges
   → marketplace auto-syncs on push to default branch
   → next session/thread in every covered scope uses skills v1.1
```

The human merge is the only gate — exactly the governance posture the framework already takes with checkpoints and `.archive/` review.

### 4.1 What belongs where (adapting the article's table)

| Skills repo (Tier 2) | Project memory `.specify/memory/` (Tier 3) |
|---|---|
| How to shape a FastEndpoints endpoint correctly | This project's schema names, cache-key prefix, RLS column |
| The HybridCache tag-invalidation pattern | This project's permission catalog and tenancy markers |
| Stack gotchas (Wolverine outbox ordering, EF `xmin` concurrency) | Which bounded contexts exist and their names |
| A review checklist any team on this stack would reuse | One-off ADR decisions, this system's invariants |

This is the framework's existing *grammar vs vocabulary* test verbatim — the skills repo simply gives the grammar its own version-controlled home.

---

## 5. Migration Roadmap

### Phase 0 — Decisions & prerequisites *(half a day)*

1. **Confirm the classification** in §2.1 (in particular: `design-principles` stays framework; `accessibility-standards` goes to `frontend-web` even though it's semi-neutral — it's loaded only for UI work).
2. **Name the repos.** Recommendation: name the skills repo after the **stack**, not the project (`dotnet-react-skills`), since the placeholder convention already makes these skills reusable across projects on the same stack. If you want per-project divergence later, fork per project.
3. **Prerequisites checklist:**
   - [ ] Private/internal GitHub repo (public repos can't be selected for claude.ai sync)
   - [ ] GitHub connector enabled for the org (claude.ai)
   - [ ] Claude GitHub App linked to the GitHub org
   - [ ] Admin access to `claude.ai/admin-settings/plugins` and Access bundles

### Phase 1 — Create the skills repository *(1 day)*

1. Scaffold the layout in §3.2: `.claude-plugin/marketplace.json`, four plugin folders, each with `.claude-plugin/plugin.json` and `skills/`.
2. `git mv`-equivalent: copy the 24 pattern skill folders from `.claude/skills/` into their plugin `skills/` folders **unchanged** — same folder names, same `SKILL.md` frontmatter `name:`, same `inject_files` pointers to `.specify/memory/*` (they still resolve against the consuming project root).
3. Fix the one intra-family reference: `data-access-patterns` inject of a sibling skill — rewrite as a plugin-relative reference or fold the needed section in.
4. Add a repo `README.md` stating the contract: *skills here must pass the grammar test — no project facts; placeholders + `.specify/memory/` pointers only* (lift `backend-architecture §1` as the contribution rule).
5. Optional but recommended: add CI that runs skill lint / plugin eval on PRs, so Claude-authored PRs get automatic feedback.

### Phase 2 — Decouple the framework *(1–2 days — the real surgery)*

1. **Routing tables → name-based + project-owned manifest.** In the nine prompt files (§2.3.1), replace literal paths with skill names, and move the *keyword→skill* tables themselves into a new project-memory file, e.g. `.specify/memory/skill-routing.md`. Framework prompts then say: *"Load the skills selected by `.specify/memory/skill-routing.md` for this role + story tags."* The framework no longer knows any stack skill exists; the routing manifest ships from the skills repo (or project template) and lives with the project.
2. **CLAUDE.md template split.** Remove the "Tech Stack Context Skills" tables from the framework's CLAUDE.md template; the skills repo provides a `CLAUDE.md.fragment` (or the routing manifest doubles as the reference) that `sk.init` merges into the project's CLAUDE.md.
3. **`setup.sh`**: no change needed to the rsync itself once pattern skills are gone from the framework's `.claude/skills/` — but add a guard that warns if legacy pattern-skill folders are found in the target project's `.claude/skills/` (pre-migration leftovers that would now shadow plugin versions).
4. **Archive the moved skills in the framework repo** using the mandated flow: `bash .claude/hooks/archive-file.sh ".claude/skills/<name>" "Moved to <skills-repo> plugin <plugin> on <date>"` for each of the 24 folders (policy: no `rm`; human reviews `.archive/ARCHIVE_LOG.md`).
5. Update `sk.init` to ask for / record the skills-marketplace repo in `project-config.md` and scaffold the settings pin (Phase 3).

### Phase 3 — Wire up consumption *(half a day)*

**Claude Code (CLI + claude.ai/code web + this repo's remote sessions):** check into each consuming project's `.claude/settings.json`:

```jsonc
{
  "extraKnownMarketplaces": {
    "dotnet-react-skills": { "source": { "source": "github", "repo": "<org>/dotnet-react-skills" } }
  },
  "enabledPlugins": {
    "backend-dotnet@dotnet-react-skills": true,
    "data-dotnet@dotnet-react-skills": true,
    "frontend-web@dotnet-react-skills": true,
    "frontend-mobile@dotnet-react-skills": true
  }
}
```
*(Exact key shapes evolve with Claude Code releases — validate with `/plugin marketplace add <org>/dotnet-react-skills` + `/plugin` UI on the current version at implementation time.)* Per-service repos enable only their slice.

**claude.ai / Claude Tag (per the article):**
1. *Admin settings → Plugins → Add plugins → Sync from GitHub* → select the repo → **Sync automatically** on → Create.
2. Access bundle → *Repositories* tab → add the skills repo (grants Claude write for PRs).
3. Same bundle → *Plugins* tab → toggle on the four plugins.

### Phase 4 — Turn on the improvement loop *(half a day)*

1. **Prompt convention** (document in the skills repo README and team runbook): when Claude gets something right after a correction, ask it to `open a PR to the skills repo updating <skill> with <learning>`.
2. **Routine** for channels where Claude works daily: weekly sweep → one consolidated PR.
3. **Review discipline**: skill PRs are reviewed like code — check the grammar test (no project facts leaked into skills), check the placeholder convention, run plugin eval.
4. **Merge → verify sync**: after the first merged PR, confirm a fresh thread/session picks up the change; document the "new threads only" propagation caveat for the team.

### Phase 5 — Cleanup & documentation *(half a day)*

1. Update framework `README.md` (Quick Start gains a "pin your stack's skills marketplace" step) and `docs/memory-guide.md` with the three-tier model.
2. Update the framework's skill-family table in the CLAUDE.md template to point at the routing manifest.
3. Remove migrated-skill `Edit(...)` permission entries from `.claude/settings.json` allow-list (they reference paths that no longer exist).
4. Tag a framework release; consuming projects do `git subtree pull` + `setup.sh` + add the settings pin.

**Total effort estimate: ~4 developer-days**, dominated by Phase 2 routing-table surgery and verification.

---

## 6. Risks & Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| **Name drift** between routing-manifest keywords and skills-repo skill names | Skills silently fail to load | CI check in the skills repo: every skill named in the shipped routing manifest exists; every skill is reachable from the manifest. Keep `name:` frontmatter frozen at migration |
| **Shadowing**: leftover copies in project `.claude/skills/` override plugin versions | Stale patterns win silently | Phase 2 setup.sh guard + one-time archive sweep in each project |
| **Claude Code plugin config shape changes** (the settings keys are still evolving) | Settings pin breaks on CLI update | Treat §5 Phase 3 JSON as indicative; validate against current docs/`/plugin` at rollout; the marketplace repo layout itself is the stable contract |
| **Public-repo limitation** | claude.ai sync unavailable | Keep the skills repo private/internal (article requirement) |
| **Propagation lag** — running sessions keep old skills | Confusion after a merge | Document "new threads pick it up"; restart long-lived sessions after skill merges |
| **Grammar/vocabulary leakage** — Claude PRs a project fact into a shared skill | Skills stop being reusable; secrets/tenancy names leak into a shared repo | PR review checklist item + the existing placeholder test; consider a CI grep for known project tokens (context names, schema names) |
| **`inject_files` relative-path assumption** — plugin skills injecting `.specify/memory/*` rely on cwd = project root | Broken injects in non-root contexts | Already the framework's operating assumption today; note it in the skills-repo README |
| **Two-repo PRs for one change** (pattern + routing keyword) | Coordination overhead | Accept: routing keywords change rarely; alternatively ship the routing manifest *from the skills repo* so both halves land in one PR |

---

## 7. Recommended Decisions (summary)

1. **Split now** — the coupling audit shows only ~9 prompt files + CLAUDE.md tables need surgery; everything else (`inject_files`, placeholder convention) already supports the split.
2. **Four plugins** mirroring the existing CLAUDE.md table sections (backend / data / frontend-web / frontend-mobile).
3. **Name the skills repo by stack**, not project, to keep the reuse story the placeholder convention already paid for.
4. **Routing manifest lives in project memory** (shipped from the skills repo), making the framework fully stack-agnostic — this is the piece that turns SpecKit-SSD-SDLC into a framework any stack can adopt.
5. **Ship the improvement loop with governance**: Claude proposes, CI evaluates, a human merges — consistent with the framework's existing checkpoint and archive policies.

---

*Report generated by Claude Code in session branch `claude/framework-project-skills-separation-j5rc2e`.*
