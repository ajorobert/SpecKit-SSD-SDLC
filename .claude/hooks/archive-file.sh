#!/usr/bin/env bash
# archive-file.sh — safe replacement for delete operations
#
# Usage:
#   bash .claude/hooks/archive-file.sh "<relative-path>" "<reason for removal>"
#
# Moves the file to .archive/YYYY-MM-DD/ and logs the action in .archive/ARCHIVE_LOG.md
# A human must review .archive/ARCHIVE_LOG.md to permanently delete archived files.

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: bash .claude/hooks/archive-file.sh \"<relative-path>\" \"<reason>\"" >&2
  echo "" >&2
  echo "Both arguments are required:" >&2
  echo "  <relative-path>  Path to the file relative to project root" >&2
  echo "  <reason>         Why this file is being removed (required for audit log)" >&2
  exit 1
fi

FILE_PATH="$1"
REASON="$2"

# Resolve project root (script lives at .claude/hooks/, so go up two levels)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Resolve the full file path
if [[ "$FILE_PATH" == /* ]]; then
  FULL_PATH="$FILE_PATH"
else
  FULL_PATH="$PROJECT_ROOT/$FILE_PATH"
fi

# Verify the file is inside the project root
CANONICAL_FILE=$(realpath -m "$FULL_PATH" 2>/dev/null || echo "$FULL_PATH")
CANONICAL_ROOT=$(realpath -m "$PROJECT_ROOT" 2>/dev/null || echo "$PROJECT_ROOT")

if [[ "$CANONICAL_FILE" != "$CANONICAL_ROOT"* ]]; then
  echo "Error: \"$FILE_PATH\" is outside project root. Cannot archive." >&2
  exit 1
fi

# Verify file exists
if [[ ! -e "$FULL_PATH" ]]; then
  echo "Error: File not found: $FULL_PATH" >&2
  exit 1
fi

# Build archive destination
DATE=$(date +%Y-%m-%d)
BASENAME=$(basename "$FULL_PATH")
ARCHIVE_DIR="$PROJECT_ROOT/.archive/$DATE"
ARCHIVE_DEST="$ARCHIVE_DIR/$BASENAME"

# Handle filename collision (append timestamp)
if [[ -e "$ARCHIVE_DEST" ]]; then
  TIMESTAMP=$(date +%H%M%S)
  ARCHIVE_DEST="$ARCHIVE_DIR/${BASENAME%.}-$TIMESTAMP"
fi

mkdir -p "$ARCHIVE_DIR"
mv "$FULL_PATH" "$ARCHIVE_DEST"

# Log entry to ARCHIVE_LOG.md
LOG_FILE="$PROJECT_ROOT/.archive/ARCHIVE_LOG.md"
RELATIVE_ARCHIVE=".archive/$DATE/$(basename "$ARCHIVE_DEST")"

cat >> "$LOG_FILE" << EOF

## $DATE — $FILE_PATH
**Reason:** $REASON
**Original path:** $FILE_PATH
**Archived to:** $RELATIVE_ARCHIVE
**Review:** [ ] approved for permanent delete
EOF

echo "Archived: $FILE_PATH -> $RELATIVE_ARCHIVE"
echo "Reason logged in .archive/ARCHIVE_LOG.md"
echo "A human must review the archive log before permanent deletion."
