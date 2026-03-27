#!/usr/bin/env bash
# Usage: create-adr.sh <number> "<title>"
# Creates a numbered ADR file in history/adr/

set -e

NUMBER=$(printf "%03d" "$1")
TITLE=$(echo "$2" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
DATE=$(date +%Y-%m-%d)
FILENAME="history/adr/ADR-${NUMBER}-${TITLE}.md"

if [ -f "$FILENAME" ]; then
  echo "ERROR: $FILENAME already exists"
  exit 1
fi

mkdir -p history/adr
touch "$FILENAME"
echo "Created: $FILENAME"
