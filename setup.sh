#!/usr/bin/env bash
# SpecKit-SSD-SDLC setup.sh
# Run after: git subtree add/pull --prefix=.speckit <url> main --squash
#
# Usage:
#   bash .speckit/setup.sh
#
# What this script does:
#   Phase 1 (always):     Sync .claude/ to project root — framework-owned, safe to overwrite
#   Phase 2 (init only):  Create CLAUDE.md, GEMINI.md, .specify/, specs/, history/ if absent
#   Phase 3 (prompted):   If CLAUDE.md or GEMINI.md already exist, ask whether to update them

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATES_ROOT="$SCRIPT_DIR/templates/root"
TEMPLATES_PROJECT="$SCRIPT_DIR/templates/project"

echo ""
echo "SpecKit-SSD-SDLC setup"
echo "Framework: $SCRIPT_DIR"
echo "Project:   $PROJECT_ROOT"
echo ""

# ─────────────────────────────────────────────
# PHASE 1: Always sync framework files
# ─────────────────────────────────────────────
echo "→ Syncing .claude/ ..."
if command -v rsync &>/dev/null; then
    rsync -a --delete "$SCRIPT_DIR/.claude/" "$PROJECT_ROOT/.claude/"
else
    mkdir -p "$PROJECT_ROOT/.claude"
    cp -r "$SCRIPT_DIR/.claude/." "$PROJECT_ROOT/.claude/"
fi
echo "  ✓ .claude/ updated"

# session.yaml is gitignored — create it if absent
if [ ! -f "$PROJECT_ROOT/.claude/session.yaml" ]; then
    cat > "$PROJECT_ROOT/.claude/session.yaml" << 'EOF'
# SpecKit-SSD-SDLC Session State
# Gitignored — never commit
# Managed by sk.session commands

role: null              # po|architect|lead|backend|frontend|backend-qa|frontend-qa|security
session_id: null        # e.g. po-20260409
branch: null            # e.g. po/session-20260409
active_intent_id: null  # e.g. CHK
active_unit_id: null    # e.g. CHK-PAY
active_story_id: null   # e.g. CHK-PAY-001
stories_touched: []     # list of story IDs worked on this session
units_touched: []       # list of unit IDs worked on this session
EOF
    echo "  ✓ .claude/session.yaml created"
fi
echo ""

# ─────────────────────────────────────────────
# PHASE 2: Init-only steps (skip if exists)
# ─────────────────────────────────────────────

# CLAUDE.md
if [ ! -f "$PROJECT_ROOT/CLAUDE.md" ]; then
    cp "$TEMPLATES_ROOT/CLAUDE.md" "$PROJECT_ROOT/CLAUDE.md"
    echo "→ Created CLAUDE.md"
    CLAUDE_CREATED=true
else
    CLAUDE_CREATED=false
fi

# GEMINI.md
if [ ! -f "$PROJECT_ROOT/GEMINI.md" ]; then
    cp "$TEMPLATES_ROOT/GEMINI.md" "$PROJECT_ROOT/GEMINI.md"
    echo "→ Created GEMINI.md"
    GEMINI_CREATED=true
else
    GEMINI_CREATED=false
fi

# .gitignore fragment
if [ -f "$TEMPLATES_ROOT/.gitignore.fragment" ]; then
    if ! grep -q "speckit-managed" "$PROJECT_ROOT/.gitignore" 2>/dev/null; then
        printf "\n# speckit-managed\n" >> "$PROJECT_ROOT/.gitignore"
        cat "$TEMPLATES_ROOT/.gitignore.fragment" >> "$PROJECT_ROOT/.gitignore"
        echo "→ Appended SpecKit entries to .gitignore"
    fi
fi

# .specify/ (full directory scaffold — project-owned content)
# Note: project-config.md is NOT created here — sk.init generates it via interview
if [ ! -d "$PROJECT_ROOT/.specify" ]; then
    cp -r "$TEMPLATES_PROJECT/.specify/" "$PROJECT_ROOT/.specify/"
    echo "→ Created .specify/ scaffold"
fi

# specs/
if [ ! -d "$PROJECT_ROOT/specs" ]; then
    cp -r "$TEMPLATES_PROJECT/specs/" "$PROJECT_ROOT/specs/"
    echo "→ Created specs/ scaffold"
fi

# history/
if [ ! -d "$PROJECT_ROOT/history" ]; then
    cp -r "$TEMPLATES_PROJECT/history/" "$PROJECT_ROOT/history/"
    echo "→ Created history/ scaffold"
fi

echo ""

# ─────────────────────────────────────────────
# PHASE 3: Prompt for CLAUDE.md / GEMINI.md updates
# (only when they already existed before this run)
# ─────────────────────────────────────────────

if [ "$CLAUDE_CREATED" = false ]; then
    echo "CLAUDE.md already exists."
    echo "Framework improvements may be available. Your project config lives in"
    echo ".specify/project-config.md and will NOT be affected."
    printf "Update CLAUDE.md with latest framework version? [y/n]: "
    read -r response
    if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
        cp "$TEMPLATES_ROOT/CLAUDE.md" "$PROJECT_ROOT/CLAUDE.md"
        echo "  ✓ CLAUDE.md updated"
    else
        echo "  ✓ CLAUDE.md kept as-is"
    fi
    echo ""
fi

if [ "$GEMINI_CREATED" = false ]; then
    echo "GEMINI.md already exists."
    echo "Framework improvements may be available. Your project config lives in"
    echo ".specify/project-config.md and will NOT be affected."
    printf "Update GEMINI.md with latest framework version? [y/n]: "
    read -r response
    if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
        cp "$TEMPLATES_ROOT/GEMINI.md" "$PROJECT_ROOT/GEMINI.md"
        echo "  ✓ GEMINI.md updated"
    else
        echo "  ✓ GEMINI.md kept as-is"
    fi
    echo ""
fi

# ─────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────
echo "✓ SpecKit setup complete."
echo ""

if [ ! -f "$PROJECT_ROOT/.specify/project-config.md" ]; then
    echo "Next step: run /sk.init in Claude Code to initialize your project."
    echo "  This will interview you and generate .specify/project-config.md"
    echo "  and all .specify/memory/ files with your project's details."
fi
echo ""
