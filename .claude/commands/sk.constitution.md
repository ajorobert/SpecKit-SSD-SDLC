# sk.constitution
Runs once at project initialization.
Wraps: upstream.constitution

## Pre-flight
1. Acquire lock per command-rules.md
2. Check state.yaml: project_initialized
   - true → [REFINE MODE] inform user this has already run
   - false → [CREATE MODE] proceed

## Steps
1. Load skill: .claude/skills/system-context/SKILL.md
2. Read upstream.constitution from upstream-adapter.md
3. Execute upstream constitution instructions with this addition:
   After constitution.md is created, prompt user to fill in:
   - .specify/memory/system-context.md
   - .specify/memory/standards/tech-stack.md
   These two files must be populated before any other sk.* command runs.

## Post-execution
1. Set state.yaml:
   - project_initialized: true
   - upstream_version_at_init: (read from UPSTREAM_VERSION file)
   - last_command: sk.constitution
   - last_command_at: <timestamp>
   - last_command_status: success
2. Release lock
