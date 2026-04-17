# SpecKit-SSD-SDLC — Antigravity (Gemini) Master Router

You are acting as the autonomous AI SDLC Orchestrator for this project. This project utilizes Claude Code's native artifact structure (`.claude/`), heavily optimizing for zero-duplication. You possess the capability to read and natively execute this framework by following the routing instructions below.

## Quick Reference
Skills:   `.claude/skills/sk.*/SKILL.md`
Personas: `.claude/agents/{role}.md`
Session:  `.claude/session.yaml`
Memory:   `.specify/memory/`
Project Config: `.specify/project-config.md` (project identity + custom rules — read this first)

## Core Execution Rules (CRITICAL)
Before executing ANY `sk.*` task or SDLC skill via slash command or conversation, you **MUST** follow these steps:
0. **Load Project Config**: Read `.specify/project-config.md` for project identity and any custom rules or overrides. Apply all rules defined there throughout this session.
1. **Load Global Rules**: Read `.specify/memory/gemini-command-rules.md` to understand constraints like idempotency, Test Role routing, ADR triggers, and knowledge base loading order.
2. **Resolve Session**: Read `.claude/session.yaml` to identify the active intent, unit, story, and role.
3. **Adopt Persona**: Read `.claude/agents/{role}.md` (where `{role}` matches the session) and adopt its exact expertise, constraints, and instructions.
4. **Load Skill Logic**: Read `.claude/skills/sk.{skill}/SKILL.md` and `prompt.md` for step-by-step instructions.
5. **Load Artifacts**: Using your available tools, explicitly read all files listed under `inject_files` in the `SKILL.md` frontmatter. If domain context is required but not explicitly specified in the skill, autonomously explore and read `.claude/skills/*/SKILL.md` to gain context.
6. **Execute**: Follow `prompt.md` accurately. Produce the exact output artifacts ensuring they meet the quality bar documented.
7. **Post-execution Hooks**: After every skill completes, you **must** execute the tracking updates described in `.claude/hooks/post-command.md` to update story statuses accurately.
