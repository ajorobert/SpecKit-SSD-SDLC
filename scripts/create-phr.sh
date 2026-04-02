#!/usr/bin/env bash
# Usage: create-phr.sh "<feature-name>"
# Creates a numbered PHR file in history/prompts/<feature>/

set -e

FEATURE=$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
DIR="history/prompts/${FEATURE}"
mkdir -p "$DIR"

# Get next number
COUNT=$(ls "$DIR"/*.md 2>/dev/null | wc -l)
NUMBER=$(printf "%03d" $((COUNT + 1)))
DATE=$(date +%Y-%m-%d)
FILENAME="${DIR}/PHR-${NUMBER}-${DATE}.md"

if [ -f "$FILENAME" ]; then
  echo "ERROR: $FILENAME already exists"
  exit 1
fi

touch "$FILENAME"
echo "Created: $FILENAME"
