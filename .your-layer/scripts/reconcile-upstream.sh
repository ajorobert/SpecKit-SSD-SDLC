#!/usr/bin/env bash
# Checks upstream for changes that may affect our layer.
# Run after: git subtree pull --prefix upstream ...

set -e

UPSTREAM_COMMANDS="upstream/templates/commands"
ADAPTER=".specify/memory/upstream-adapter.md"

echo "=== Upstream Reconciliation Report ==="
echo "Date: $(date)"
echo ""

echo "--- Checking adapter paths ---"
while IFS= read -r line; do
  if [[ "$line" =~ upstream/.*\.md ]]; then
    PATH_MATCH=$(echo "$line" | grep -o 'upstream/[^ ]*')
    if [ ! -f "$PATH_MATCH" ]; then
      echo "BROKEN: $PATH_MATCH"
    else
      echo "OK:     $PATH_MATCH"
    fi
  fi
done < "$ADAPTER"

echo ""
echo "--- New files in upstream commands ---"
ls "$UPSTREAM_COMMANDS"/*.md 2>/dev/null

echo ""
echo "=== End Report ==="
echo "Review any BROKEN paths and update .specify/memory/upstream-adapter.md"
