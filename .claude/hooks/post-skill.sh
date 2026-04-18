#!/usr/bin/env bash
# PostToolUse hook — fires when the Skill tool is invoked.
#
# Unconditional skills (no pass/fail): update story status immediately.
# Conditional skills (need pass/fail from response): write .last-skill so
# the Stop hook (post-response.sh) can finish the job after Claude responds.
#
# Exit 0 always — this hook is bookkeeping only and must never block Claude.

INPUT=$(cat)

# Parse skill name from .tool_input.skill
SKILL_NAME=$(echo "$INPUT" | jq -r '.tool_input.skill // empty' 2>/dev/null)

# If empty or does not start with "sk." → exit
if [[ -z "$SKILL_NAME" ]] || [[ "$SKILL_NAME" != sk.* ]]; then
  exit 0
fi

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
SESSION_YAML="${PROJECT_ROOT}/.claude/session.yaml"
LAST_SKILL_FILE="${PROJECT_ROOT}/.claude/.last-skill"

# Conditional skills — defer to Stop hook; write .last-skill and exit
case "$SKILL_NAME" in
  sk.test|sk.review|sk.verify)
    echo "$SKILL_NAME" > "$LAST_SKILL_FILE" 2>/dev/null || true
    exit 0
    ;;
esac

# Unconditional skills — map to status and update story file now
case "$SKILL_NAME" in
  sk.specify)  NEW_STATUS="draft"    ;;
  sk.plan)     NEW_STATUS="ready"    ;;
  sk.implement) NEW_STATUS="testing" ;;
  sk.ship)     NEW_STATUS="shipped"  ;;
  *)           exit 0                ;;
esac

# Read ACTIVE_STORY_ID from session.yaml (pure bash — no yq or python)
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

# Find story file via glob
shopt -s nullglob
STORY_FILES=("${PROJECT_ROOT}/specs/intents"/*/units/*/stories/"story-${ACTIVE_STORY_ID}.md")
shopt -u nullglob

if [[ ${#STORY_FILES[@]} -eq 0 ]]; then
  echo "post-skill.sh: WARNING — story file not found for ID: ${ACTIVE_STORY_ID}" >&2
  exit 0
fi

if [[ ${#STORY_FILES[@]} -gt 1 ]]; then
  echo "post-skill.sh: WARNING — multiple story files matched for ID: ${ACTIVE_STORY_ID}, using first" >&2
fi

STORY_FILE="${STORY_FILES[0]}"

if ! grep -qE '^status:' "$STORY_FILE" 2>/dev/null; then
  echo "post-skill.sh: WARNING — no 'status:' field in frontmatter: ${STORY_FILE}" >&2
  exit 0
fi

sed -i "s/^status:.*$/status: ${NEW_STATUS}/" "$STORY_FILE" 2>/dev/null || {
  echo "post-skill.sh: WARNING — failed to update status in: ${STORY_FILE}" >&2
  exit 0
}

AUDIT_LOG="${PROJECT_ROOT}/.claude/skill-audit.log"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "${TIMESTAMP} | ${SKILL_NAME} | ${ACTIVE_STORY_ID} | ${NEW_STATUS}" >> "$AUDIT_LOG" 2>/dev/null || true

exit 0
