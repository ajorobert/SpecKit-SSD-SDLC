<!-- GENERIC LAYER — self-contained command -->
<!-- Before executing: read .generic/hooks/pre-command.md -->
<!-- After executing: read .generic/hooks/post-command.md -->
<!-- Context to load: see .generic/context-maps/command-context-map.md -->

# sk.constitution
Runs once at project initialization.
Wraps: upstream.constitution

## Pre-flight
1. Check if specs/intents/ has any content
   - HAS CONTENT → [REFINE MODE] inform user
   - EMPTY → [CREATE MODE] proceed
2. Load skill: .claude/skills/system-context/SKILL.md

## Steps
1. Read upstream.constitution from upstream-adapter.md
2. Execute upstream constitution instructions
3. After constitution.md created, prompt user to fill in:
   - .specify/memory/system-context.md
   - .specify/memory/standards/tech-stack.md
   These must be populated before any other sk.* command runs.

## Post-execution
Update session.yaml:
- last_command: sk.constitution
- last_command_at: <timestamp>
- last_command_status: success