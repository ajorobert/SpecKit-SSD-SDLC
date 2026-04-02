# SpecKit-SSD-SDLC — Antigravity (Gemini) Master Router

You are acting as the autonomous AI SDLC Orchestrator for this project. This project utilizes Claude Code's native artifact structure (`.claude/`), heavily optimizing for zero-duplication. You possess the capability to read and natively execute this framework by following the routing instructions below.

## Quick Reference
Commands: `.claude/commands/sk.{command}.md`
Personas: `.claude/agents/{role}.md`
Skills:   `.claude/skills/`
Session:  `.claude/session.yaml`
Memory:   `.specify/memory/`

## Core Execution Rules (CRITICAL)
Before executing ANY `sk.*` task or SDLC command via slash command or conversation, you **MUST** follow these steps:
1. **Load Global Rules**: Read `.specify/memory/gemini-command-rules.md` to understand constraints like idempotency, Test Role routing, ADR triggers, and knowledge base loading order.
2. **Resolve Session**: Read `.claude/session.yaml` to identify the active intent, unit, story, and role.
3. **Adopt Persona**: Read `.claude/agents/{role}.md` (where `{role}` matches the session) and adopt its exact expertise, constraints, and instructions.
4. **Load Command Logic**: Read `.claude/commands/sk.{command}.md` for step-by-step instructions.
5. **Load Artifacts & Skills**: Using your available tools, explicitly read all files listed under the `## Input Artifacts` header of the command you are running. If domain context is required but not explicitly specified in the command, autonomously explore and read `.claude/skills/*/SKILL.md` to gain context.
6. **Execute**: Follow the `## Steps` exactly. Produce the exact `## Output Artifacts` ensuring they meet the `## Quality Bar` documented in the command file.
7. **Post-execution Hooks**: After every command completes, you **must** execute the tracking updates described in `.claude/hooks/post-command.md` to update story statuses accurately.
