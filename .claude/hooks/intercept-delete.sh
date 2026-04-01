#!/usr/bin/env bash
# PreToolUse hook — intercepts delete commands and redirects to archive workflow
# Exit 2 = block; Exit 0 = allow

set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [[ -z "$COMMAND" ]]; then
  exit 0
fi

# Detect delete-family commands
if echo "$COMMAND" | grep -qiE '^\s*(rm\s|rm$|rmdir\s|del\s|unlink\s|Remove-Item\s)'; then
  echo "Direct deletion is blocked in this project." >&2
  echo "" >&2
  echo "To remove a file, use the archive script instead:" >&2
  echo "  bash .claude/hooks/archive-file.sh \"<relative-path>\" \"<reason for removal>\"" >&2
  echo "" >&2
  echo "This moves the file to .archive/ and logs it for human review." >&2
  exit 2
fi

# Block piped or chained rm (e.g., find ... | rm, something && rm)
if echo "$COMMAND" | grep -qE '\|\s*rm\s|\|\s*rm$|&&\s*rm\s|&&\s*rm$|;\s*rm\s|;\s*rm$'; then
  echo "Piped or chained deletion is blocked in this project." >&2
  echo "Use: bash .claude/hooks/archive-file.sh \"<path>\" \"<reason>\"" >&2
  exit 2
fi

exit 0
