#!/usr/bin/env bash
# PreToolUse hook — validates that Edit/Write targets stay within the project root
# Exit 2 = block; Exit 0 = allow

set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Reject obvious path traversal attempts
if echo "$FILE_PATH" | grep -qE '\.\.(/|\\)'; then
  echo "Blocked: path traversal detected in \"$FILE_PATH\"" >&2
  echo "All file operations must stay within the project root: $PROJECT_ROOT" >&2
  exit 2
fi

# Reject absolute paths to system directories
SYSTEM_PREFIXES=("/etc/" "/usr/" "/bin/" "/sbin/" "/lib/" "/boot/" "/sys/" "/proc/" "/root/" "/var/")
for PREFIX in "${SYSTEM_PREFIXES[@]}"; do
  if [[ "$FILE_PATH" == "$PREFIX"* ]] || [[ "$FILE_PATH" == "//$PREFIX"* ]]; then
    echo "Blocked: attempt to edit system path \"$FILE_PATH\"" >&2
    echo "All file operations must stay within the project root: $PROJECT_ROOT" >&2
    exit 2
  fi
done

# Reject home-directory paths (~/... or /home/...)
if [[ "$FILE_PATH" == "~/"* ]] || [[ "$FILE_PATH" == "/home/"* ]]; then
  echo "Blocked: attempt to edit home directory path \"$FILE_PATH\"" >&2
  echo "All file operations must stay within the project root: $PROJECT_ROOT" >&2
  exit 2
fi

# If path is absolute, verify it resolves inside the project root
if [[ "$FILE_PATH" == /* ]]; then
  # Resolve canonical path if possible (may not exist yet for new files)
  RESOLVED=$(realpath -m "$FILE_PATH" 2>/dev/null || echo "$FILE_PATH")
  PROJECT_RESOLVED=$(realpath -m "$PROJECT_ROOT" 2>/dev/null || echo "$PROJECT_ROOT")

  if [[ "$RESOLVED" != "$PROJECT_RESOLVED"* ]]; then
    echo "Blocked: \"$FILE_PATH\" is outside project root." >&2
    echo "Project root: $PROJECT_ROOT" >&2
    exit 2
  fi
fi

exit 0
