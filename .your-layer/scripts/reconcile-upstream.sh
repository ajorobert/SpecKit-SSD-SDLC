#!/usr/bin/env bash
# reconcile-upstream.sh
# Run after: git subtree pull --prefix upstream ...
# Checks upstream changes that may affect SpecKit-SSD-SDLC layer

set -e

UPSTREAM_COMMANDS="upstream/templates/commands"
ADAPTER=".specify/memory/upstream-adapter.md"
REPORT_DIR=".your-layer/reconcile-reports"
DATE=$(date +%Y-%m-%d)
SEQUENCE=$(printf "%02d" $(ls "$REPORT_DIR"/reconcile-"$DATE"-*.md \
           2>/dev/null | wc -l | xargs -I{} expr {} + 1))
REPORT="$REPORT_DIR/reconcile-${DATE}-${SEQUENCE}.md"
EXCLUDED_UPSTREAM="taskstoissues.md"



mkdir -p "$REPORT_DIR"

echo "# Upstream Reconciliation Report" > "$REPORT"
echo "Date: $DATE" >> "$REPORT"
echo "Upstream: $(cat UPSTREAM_VERSION | grep upstream_source | cut -d: -f2)" \
     >> "$REPORT"
echo "" >> "$REPORT"

BROKEN=0
WARNS=0

echo "## Adapter Path Check" >> "$REPORT"
echo "" >> "$REPORT"

while IFS= read -r line; do
  if [[ "$line" =~ upstream/.*\.md ]]; then
    FPATH=$(echo "$line" | grep -o 'upstream/[^ ]*')
    if [ ! -f "$FPATH" ]; then
      echo "- ❌ BROKEN: $FPATH" >> "$REPORT"
      BROKEN=$((BROKEN + 1))
    else
      echo "- ✅ OK: $FPATH" >> "$REPORT"
    fi
  fi
done < "$ADAPTER"

echo "" >> "$REPORT"
echo "## New Files in Upstream Commands" >> "$REPORT"
echo "" >> "$REPORT"

for f in "$UPSTREAM_COMMANDS"/*.md; do
  BASENAME=$(basename "$f")
  if [[ "$EXCLUDED_UPSTREAM" == *"$BASENAME"* ]]; then
    echo "- ⏭️  Excluded (intentional): $BASENAME"
    continue
  fi
  if ! grep -q "$BASENAME" "$ADAPTER"; then
    echo "- ⚠️  NEW (not in adapter): $BASENAME" >> "$REPORT"
    WARNS=$((WARNS + 1))
  else
    echo "- ✅ Mapped: $BASENAME" >> "$REPORT"
  fi
done

echo "" >> "$REPORT"
echo "## Upstream Template Changes" >> "$REPORT"
echo "" >> "$REPORT"

for f in "$UPSTREAM_COMMANDS"/*.md; do
  BASENAME=$(basename "$f")
  GITLOG=$(git log --oneline -1 "upstream/templates/commands/$BASENAME" \
           2>/dev/null || echo "unknown")
  echo "- $BASENAME: $GITLOG" >> "$REPORT"
done

echo "" >> "$REPORT"
echo "## Summary" >> "$REPORT"
echo "- Broken paths: $BROKEN" >> "$REPORT"
echo "- New upstream files not in adapter: $WARNS" >> "$REPORT"
echo "" >> "$REPORT"

if [ $BROKEN -gt 0 ]; then
  echo "## Action Required" >> "$REPORT"
  echo "Update .specify/memory/upstream-adapter.md for broken paths" \
       >> "$REPORT"
  echo "Run: grep -n 'BROKEN' $REPORT" >> "$REPORT"
fi

if [ $WARNS -gt 0 ]; then
  echo "" >> "$REPORT"
  echo "## Optional Actions" >> "$REPORT"
  echo "New upstream commands detected — consider adding sk.* wrappers" \
       >> "$REPORT"
fi

echo "Report written to: $REPORT"
echo ""
echo "Broken paths: $BROKEN"
echo "New upstream files: $WARNS"

if [ $BROKEN -gt 0 ]; then
  echo ""
  echo "⚠️  Action required — see report for details"
  exit 1
fi

exit 0
