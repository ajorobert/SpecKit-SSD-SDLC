#!/usr/bin/env bash
# Stop hook — fires after every Claude response.
# Only acts when post-skill.sh left a .last-skill file (sk.test / sk.review / sk.verify).
# Reads the transcript to find SK_RESULT: PASS or SK_RESULT: FAIL emitted by the skill.
# Exit 0 always — this hook is bookkeeping only and must never block Claude.

INPUT=$(cat)

# Guard: if Claude is responding to hook output, do not recurse
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
if [[ "$STOP_HOOK_ACTIVE" == "true" ]]; then
  exit 0
fi

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
LAST_SKILL_FILE="${PROJECT_ROOT}/.claude/.last-skill"

# No .last-skill → no conditional skill was recently invoked → nothing to do
if [[ ! -f "$LAST_SKILL_FILE" ]]; then
  exit 0
fi

# Read skill name and immediately remove the file (even if we fail below)
SKILL_NAME=$(cat "$LAST_SKILL_FILE" 2>/dev/null | xargs)
rm -f "$LAST_SKILL_FILE" 2>/dev/null || true

if [[ -z "$SKILL_NAME" ]]; then
  exit 0
fi

# Map skill → status on PASS
case "$SKILL_NAME" in
  sk.test)   NEW_STATUS="review"  ;;
  sk.review) NEW_STATUS="verify"  ;;
  sk.verify) NEW_STATUS="done"    ;;
  *)         exit 0               ;;
esac

# Read transcript path from hook payload
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
if [[ -z "$TRANSCRIPT_PATH" ]] || [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  exit 0
fi

# Find the last assistant message in the transcript (JSONL, one object per line)
# tac reverses the file so grep -m1 hits the most recent assistant entry first
LAST_ASSISTANT_LINE=$(tac "$TRANSCRIPT_PATH" | grep -m1 '"type":"assistant"' 2>/dev/null || true)

if [[ -z "$LAST_ASSISTANT_LINE" ]]; then
  exit 0
fi

# Extract text content — handles both string and array content shapes
LAST_TEXT=$(echo "$LAST_ASSISTANT_LINE" | jq -r '
  .message.content |
  if type == "string" then .
  elif type == "array" then (map(select(.type == "text") | .text) | join(""))
  else ""
  end
' 2>/dev/null || true)

# Check for the structured completion marker emitted by the skill prompt
if ! echo "$LAST_TEXT" | grep -q "^SK_RESULT: PASS"; then
  exit 0
fi

# Skill passed — update story status
SESSION_YAML="${PROJECT_ROOT}/.claude/session.yaml"
if [[ ! -f "$SESSION_YAML" ]]; then
  exit 0
fi

ACTIVE_STORY_ID=$(grep -E '^active_story_id:' "$SESSION_YAML" \
  | sed 's/^active_story_id:[[:space:]]*//' \
  | sed 's/[[:space:]]*#.*//' \
  | tr -d '"' \
  | xargs 2>/dev/null || true)

if [[ -z "$ACTIVE_STORY_ID" ]] || [[ "$ACTIVE_STORY_ID" == "null" ]]; then
  exit 0
fi

shopt -s nullglob
STORY_FILES=("${PROJECT_ROOT}/specs/intents"/*/units/*/stories/"story-${ACTIVE_STORY_ID}.md")
shopt -u nullglob

if [[ ${#STORY_FILES[@]} -eq 0 ]]; then
  echo "post-response.sh: WARNING — story file not found for ID: ${ACTIVE_STORY_ID}" >&2
  exit 0
fi

if [[ ${#STORY_FILES[@]} -gt 1 ]]; then
  echo "post-response.sh: WARNING — multiple story files matched for ID: ${ACTIVE_STORY_ID}, using first" >&2
fi

STORY_FILE="${STORY_FILES[0]}"

if ! grep -qE '^status:' "$STORY_FILE" 2>/dev/null; then
  echo "post-response.sh: WARNING — no 'status:' field in frontmatter: ${STORY_FILE}" >&2
  exit 0
fi

sed -i "s/^status:.*$/status: ${NEW_STATUS}/" "$STORY_FILE" 2>/dev/null || {
  echo "post-response.sh: WARNING — failed to update status in: ${STORY_FILE}" >&2
  exit 0
}

AUDIT_LOG="${PROJECT_ROOT}/.claude/skill-audit.log"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "${TIMESTAMP} | ${SKILL_NAME} | ${ACTIVE_STORY_ID} | ${NEW_STATUS}" >> "$AUDIT_LOG" 2>/dev/null || true

exit 0
