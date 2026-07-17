#!/bin/bash
# PreToolUse hook: warn if pushing with un-deployed backend changes
# Global hook — works across all projects
# Detects Convex (convex/ dir) and Modal (.py files) automatically

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$PROJECT_ROOT" ]; then
    echo '{"result":"approve"}'
    exit 0
fi

BRANCH=$(git branch --show-current 2>/dev/null)
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo main)
WARNINGS=""

# ── Convex Check ──
if [ -d "$PROJECT_ROOT/convex" ]; then
    CONVEX_CHANGES=$(git diff "$DEFAULT_BRANCH" --name-only 2>/dev/null | grep '^convex/' | grep -v '_generated/' | grep -v '\.test\.')
    if [ -n "$CONVEX_CHANGES" ]; then
        COUNT=$(echo "$CONVEX_CHANGES" | wc -l | tr -d ' ')
        FILES=$(echo "$CONVEX_CHANGES" | head -5 | sed 's/^/  - /')
        if [ "$BRANCH" = "main" ]; then
            CMD="/deploy (→ ./deploy-backend.sh)"
            ENV="PRODUCTION"
        else
            CMD="/deploy (→ ./deploy-backend-preview.sh)"
            ENV="DEV"
        fi
        WARNINGS="${WARNINGS}⚠️  CONVEX: ${COUNT} file(s) changed → ${ENV}\n${FILES}\nDeploy: ${CMD}\n\n"
    fi
fi

# ── Modal Check (if .py files changed and modal is in deps) ──
if [ -f "$PROJECT_ROOT/pyproject.toml" ] && grep -q "modal" "$PROJECT_ROOT/pyproject.toml" 2>/dev/null; then
    MODAL_CHANGES=$(git diff "$DEFAULT_BRANCH" --name-only 2>/dev/null | grep '\.py$' | grep -v 'test' | grep -v '__pycache__')
    if [ -n "$MODAL_CHANGES" ]; then
        COUNT=$(echo "$MODAL_CHANGES" | wc -l | tr -d ' ')
        if [ "$BRANCH" = "main" ]; then
            MODAL_ENV="PRODUCTION"
        else
            MODAL_ENV="DEV"
        fi
        WARNINGS="${WARNINGS}⚠️  MODAL: ${COUNT} Python file(s) changed → ${MODAL_ENV}\nDeploy: /deploy\n\n"
    fi
fi

# ── Result ──
if [ -z "$WARNINGS" ]; then
    echo '{"result":"approve"}'
else
    MSG=$(printf '%s' "$WARNINGS" | sed 's/"/\\"/g')
    cat <<EOF
{
  "result": "warn",
  "message": "${MSG}Without backend deploy → frontend will crash at runtime."
}
EOF
fi
