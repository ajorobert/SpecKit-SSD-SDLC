#!/usr/bin/env bash
# PostToolUse hook — warns when a system-prompt file is modified.
# These files are @imported into CLAUDE.md and inlined at session start.
# Modifying them mid-session leaves the active system prompt stale.
#
# Exit 0 always — this hook is advisory only, never blocking.

set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Files included in the system prompt via @imports in CLAUDE.md.
# Keep this list in sync with the @import section of CLAUDE.md.
SYSTEM_PROMPT_FILES=(
  "CLAUDE.md"
  "specs/knowledge-base.md"
  ".specify/memory/command-rules.md"
  ".specify/project-config.md"
)

# Normalize: strip project root prefix so we can compare relative paths.
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
# Remove trailing slash
PROJECT_ROOT="${PROJECT_ROOT%/}"

# Attempt to derive a relative path from an absolute one.
# Works for both Unix and Windows-style paths passed through bash.
RELATIVE_PATH="$FILE_PATH"
if [[ "$FILE_PATH" == "$PROJECT_ROOT"* ]]; then
  RELATIVE_PATH="${FILE_PATH#$PROJECT_ROOT}"
  RELATIVE_PATH="${RELATIVE_PATH#/}"
  RELATIVE_PATH="${RELATIVE_PATH#\\}"
fi

# Normalize backslashes to forward slashes (Windows paths via bash).
RELATIVE_PATH="${RELATIVE_PATH//\\//}"

for SP_FILE in "${SYSTEM_PROMPT_FILES[@]}"; do
  if [[ "$RELATIVE_PATH" == "$SP_FILE" ]]; then
    echo ""
    echo "⚠️  SYSTEM PROMPT FILE MODIFIED: $SP_FILE"
    echo "   This file is @imported into CLAUDE.md and loaded at session start."
    echo "   The current session's system prompt is now STALE."
    echo "   ➜  Restart Claude Code before continuing to reload updated context."
    echo ""
    exit 0
  fi
done

exit 0
