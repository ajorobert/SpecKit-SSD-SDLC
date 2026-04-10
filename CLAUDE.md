<!-- SPECKIT-SSD-SDLC MANAGED -->

# SpecKit-SSD-SDLC

## Identity
Spec-driven development framework for full-stack multi-service systems.
Read .specify/project-config.md for project identity, custom rules, and overrides.
Commands: .claude/commands/sk.*.md
Agents: .claude/agents/
Skills: .claude/skills/ (auto-loaded by context)
Roles: po | architect | lead | backend | frontend | backend-qa | frontend-qa | security

## System Prompt Inclusions
<!-- These files are inlined at session start via @imports.
     Modifying any of them mid-session leaves the system prompt stale.
     A PostToolUse hook will warn you when this happens — restart Claude Code to reload. -->
@specs/knowledge-base.md
@.specify/memory/command-rules.md

## Rules
1. command-rules.md is loaded above via @import — no need to re-read it per command.
2. upstream/ is a pattern reference archive — not executed at runtime. See upstream-adapter.md for migration rationale.
3. Never edit files inside upstream/
4. Session state: .claude/session.yaml

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
