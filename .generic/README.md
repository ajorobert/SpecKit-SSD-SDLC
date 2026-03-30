# SpecKit-SSD-SDLC Generic Layer

Platform-agnostic execution layer. Works with any AI coding assistant
that supports markdown-based instructions.

## Supported Tools
- Cursor (.cursorrules)
- Windsurf (.windsurfrules)
- Gemini CLI (GEMINI.md)
- Codex CLI (AGENTS.md)
- Antigravity (AGENTS.md)
- Any agent that reads AGENTS.md or markdown command files

## How to Use
1. Tell your agent to read .generic/AGENTS.md for project context
2. Reference commands as: .generic/commands/sk.{command}.md
3. Session state: .generic/session.yaml (gitignored)

## Difference from Claude Code layer
Commands in .generic/commands/ are self-contained.
They carry all context loading instructions explicitly.
No platform hooks or auto-loading — everything is in the command file.

## Key Files
- AGENTS.md              ← start here, gives agent full project context
- commands/              ← sk.* command definitions
- personas/              ← role-based agent personas
- context-maps/          ← explicit context loading instructions
- hooks/                 ← pre/post command instructions (inline)
