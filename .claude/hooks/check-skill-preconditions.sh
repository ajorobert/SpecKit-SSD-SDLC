#!/usr/bin/env bash
# PreToolUse hook — checks a skill's declared preconditions before invocation.
# Exit 2 = block; Exit 0 = allow.
#
# Reads the `preconditions:` YAML block from .claude/skills/<skill>/SKILL.md
# and evaluates each entry. Supported forms:
#   - story.<field> == <value>
#   - story.<field> != <value>
#   - story.<dotted.path> == <value>       (e.g. story.status.current)
#   - file_exists: <glob>
#
# Story fields come from the active story's frontmatter, located via
# active_story_id in session.yaml.

set -uo pipefail

INPUT=$(cat)
# Extract skill name — prefer jq, fall back to sed (jq may be absent on Windows bash)
if command -v jq >/dev/null 2>&1; then
  SKILL_NAME=$(echo "$INPUT" | jq -r '.tool_input.skill // empty' 2>/dev/null)
else
  SKILL_NAME=$(echo "$INPUT" | sed -n 's/.*"skill"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
fi

if [[ -z "$SKILL_NAME" ]] || [[ "$SKILL_NAME" != sk.* ]]; then
  exit 0
fi

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
SKILL_FILE="${PROJECT_ROOT}/.claude/skills/${SKILL_NAME}/SKILL.md"
SESSION_YAML="${PROJECT_ROOT}/.claude/session.yaml"

[[ -f "$SKILL_FILE" ]] || exit 0

# Extract preconditions block (lines between `preconditions:` and the next top-level key or `---`)
PRECONDS=$(awk '
  /^preconditions:[[:space:]]*$/ { in_block=1; next }
  in_block && /^[a-zA-Z_][a-zA-Z0-9_-]*:/ { in_block=0 }
  in_block && /^---[[:space:]]*$/ { in_block=0 }
  in_block && /^[[:space:]]*-[[:space:]]/ {
    sub(/^[[:space:]]*-[[:space:]]*/, "")
    print
  }
' "$SKILL_FILE")

[[ -z "$PRECONDS" ]] && exit 0

# Locate active story frontmatter (may be absent — some preconditions don't need it)
STORY_FILE=""
if [[ -f "$SESSION_YAML" ]]; then
  ACTIVE_STORY_ID=$(grep -E '^active_story_id:' "$SESSION_YAML" \
    | sed 's/^active_story_id:[[:space:]]*//' \
    | sed 's/[[:space:]]*#.*//' \
    | tr -d '"' \
    | xargs 2>/dev/null || true)
  if [[ -n "$ACTIVE_STORY_ID" ]] && [[ "$ACTIVE_STORY_ID" != "null" ]]; then
    shopt -s nullglob
    MATCHES=("${PROJECT_ROOT}/specs/intents"/*/units/*/stories/"story-${ACTIVE_STORY_ID}.md")
    shopt -u nullglob
    [[ ${#MATCHES[@]} -gt 0 ]] && STORY_FILE="${MATCHES[0]}"
  fi
fi

# Read a frontmatter field via dotted path from the story file.
# Understands flat (`test-status: pass`) and nested (`status:\n  current: shipped`) YAML.
story_field() {
  local path="$1"
  [[ -z "$STORY_FILE" ]] && { echo ""; return; }

  awk -v path="$path" '
    BEGIN {
      n = split(path, parts, ".")
      fm = 0
    }
    /^---[[:space:]]*$/ {
      fm++
      if (fm == 2) exit
      next
    }
    fm != 1 { next }

    {
      # indent = leading spaces
      match($0, /^[[:space:]]*/)
      indent = RLENGTH
      line = substr($0, indent + 1)
      # skip comments / blanks
      if (line ~ /^#/ || line == "") next
      # parse key: value
      if (match(line, /^[A-Za-z_][A-Za-z0-9_-]*:/)) {
        key = substr(line, 1, RLENGTH - 1)
        rest = substr(line, RLENGTH + 1)
        sub(/^[[:space:]]*/, "", rest)
        sub(/[[:space:]]*#.*$/, "", rest)
        gsub(/^["'\'']|["'\'']$/, "", rest)
      } else next

      # depth 0: top-level; depth 1: indent 2; etc.
      depth = int(indent / 2)

      if (depth >= n) next
      if (key != parts[depth + 1]) next

      if (depth == n - 1) {
        print rest
        exit
      }
      # else descend — just continue; we track by matching key per depth
    }
  ' "$STORY_FILE"
}

FAIL=0
FAIL_MESSAGES=()

while IFS= read -r RULE; do
  RULE=$(echo "$RULE" | sed 's/[[:space:]]*#.*$//' | xargs)
  [[ -z "$RULE" ]] && continue

  # file_exists: <glob>
  if [[ "$RULE" =~ ^file_exists:[[:space:]]*(.+)$ ]]; then
    GLOB="${BASH_REMATCH[1]}"
    shopt -s nullglob
    MATCHES=( ${PROJECT_ROOT}/${GLOB} )
    shopt -u nullglob
    if [[ ${#MATCHES[@]} -eq 0 ]]; then
      FAIL=1
      FAIL_MESSAGES+=("  - required file(s) not found: ${GLOB}")
    fi
    continue
  fi

  # story.<path> (==|!=) <value>
  if [[ "$RULE" =~ ^story\.([A-Za-z0-9_.-]+)[[:space:]]*(==|!=)[[:space:]]*(.+)$ ]]; then
    PATH_EXPR="${BASH_REMATCH[1]}"
    OP="${BASH_REMATCH[2]}"
    EXPECTED="${BASH_REMATCH[3]}"
    EXPECTED=$(echo "$EXPECTED" | sed 's/^["'\'']//; s/["'\'']$//' | xargs)
    ACTUAL=$(story_field "$PATH_EXPR")

    if [[ -z "$STORY_FILE" ]]; then
      FAIL=1
      FAIL_MESSAGES+=("  - no active story found — cannot evaluate: ${RULE}")
      continue
    fi

    case "$OP" in
      "==")
        if [[ "$ACTUAL" != "$EXPECTED" ]]; then
          FAIL=1
          FAIL_MESSAGES+=("  - story.${PATH_EXPR} is \"${ACTUAL:-<empty>}\", expected \"${EXPECTED}\"")
        fi
        ;;
      "!=")
        if [[ "$ACTUAL" == "$EXPECTED" ]]; then
          FAIL=1
          FAIL_MESSAGES+=("  - story.${PATH_EXPR} is \"${ACTUAL}\", must not equal \"${EXPECTED}\"")
        fi
        ;;
    esac
    continue
  fi

  # Unknown rule form — warn but don't block
  echo "check-skill-preconditions.sh: WARNING — unrecognized rule: ${RULE}" >&2
done <<< "$PRECONDS"

if [[ "$FAIL" -eq 1 ]]; then
  echo "Skill \"${SKILL_NAME}\" blocked — preconditions not met:" >&2
  for MSG in "${FAIL_MESSAGES[@]}"; do
    echo "$MSG" >&2
  done
  echo "" >&2
  echo "See ${SKILL_FILE#$PROJECT_ROOT/} for the declared preconditions." >&2
  exit 2
fi

exit 0
