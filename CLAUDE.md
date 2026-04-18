<!-- SPECKIT-SSD-SDLC MANAGED -->

# SpecKit-SSD-SDLC

## Identity
Spec-driven development framework for full-stack multi-service systems.
Read .specify/project-config.md for project identity, custom rules, and overrides.
Skills: .claude/skills/sk.*/SKILL.md
Agents: .claude/agents/
Context skills: .claude/skills/{governance,design-principles,domain-model,service-registry,standards,system-context,architecture-decisions}/
Roles: po | architect | lead | backend | frontend | security

## System Prompt Inclusions
<!-- specs/knowledge-base.md is inlined at session start via @import.
     Modifying it mid-session leaves the system prompt stale.
     A PostToolUse hook will warn you when this happens — restart Claude Code to reload. -->
@specs/knowledge-base.md

## Rules
1. Skills are located in .claude/skills/sk.*/. Each skill declares its own inject_files and subagent_type. command-rules.md is no longer globally imported — relevant rules are embedded per skill.
2. Session state: .claude/session.yaml

## Tech Stack Context Skills
These are passive knowledge packs — never invoked directly. They are loaded via inject_files in the relevant sk.* skills based on the work being done.

### Backend
| Skill folder | Load when |
|---|---|
| `csharp-clean-arch` | Any C# .NET 10 backend implementation or review |
| `design-code-review` | Backend code review (sk.review) |
| `bff-patterns` | BFF API layer design or implementation |
| `messaging-patterns` | RabbitMQ, MassTransit, MediatR, Hangfire work |
| `workflow-patterns` | Elsa v3 workflows, SLA timers, breach alerts |
| `auth-patterns` | Firebase/Keycloak auth, session storage, authorization |

### Data
| Skill folder | Load when |
|---|---|
| `postgresql-patterns` | Schema design, migrations, data modeling |
| `redis-patterns` | Caching, session cache, rate limiting, distributed locks |
| `elasticsearch-patterns` | Search index design, geo search, ES queries |
| `file-storage-patterns` | File upload, image pipeline, virus scan, CDN delivery |

### Frontend — Customer Portal
| Skill folder | Load when |
|---|---|
| `nextjs-patterns` | Next.js App Router, NextAuth v5, Strapi CMS, R2 images |
| `frontend-design-system` | Tailwind v4, shadcn/ui, dark mode, design tokens |
| `react-component-patterns` | Component decomposition, TypeScript props, form handling |
| `zustand-state-management` | Global/shared UI state |
| `accessibility-standards` | Any frontend implementation or UAT |

### Frontend — Admin SPA
| Skill folder | Load when |
|---|---|
| `react-admin-patterns` | React + Vite + Tanstack Router admin SPA |
| `frontend-design-system` | Tailwind v4, shadcn/ui (same as portal) |
| `react-component-patterns` | Component patterns (same as portal) |
| `zustand-state-management` | Global state (same as portal) |
| `accessibility-standards` | Any frontend implementation or UAT |

### Frontend — Mobile App
| Skill folder | Load when |
|---|---|
| `react-native-patterns` | React Native + Expo managed workflow, NativeWind v5 |

## Security Rules
5. Never use `rm`, `rmdir`, `del`, or `unlink` — these commands are blocked by policy.
6. To remove a file, use the archive script: `bash .claude/hooks/archive-file.sh "<relative-path>" "<reason for removal>"`
   - This moves the file to `.archive/YYYY-MM-DD/` and logs it for human review.
   - A human must review `.archive/ARCHIVE_LOG.md` before any permanent deletion.
7. Never edit or write files outside the project root directory. All file paths must resolve within the project root.
8. The `.archive/` folder is human-review territory — never delete files from it.

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
