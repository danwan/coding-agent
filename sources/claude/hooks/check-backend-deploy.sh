#!/bin/bash
# PreToolUse hook: warn when pushing with un-deployed backend changes.
# Global hook — works across all projects. Detects Convex (convex/ dir) and
# Modal (modal in pyproject.toml) automatically.
#
# Enforces CLAUDE.md Golden Rule #7: Convex and Modal do NOT auto-deploy, so a
# push that ships frontend code referencing un-deployed backend changes crashes
# at runtime.
#
# Compares against origin/<default-branch>, NOT the local default branch.
# Diffing against the branch you are standing on always yields empty, which
# silently disabled this guard on main — i.e. exactly in production.
#
# Wire with `if: "Bash(git push*)"` so it runs on pushes, not on every Bash call.

emit_allow() {
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
  exit 0
}

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || emit_allow
[ -z "$PROJECT_ROOT" ] && emit_allow

BRANCH=$(git branch --show-current 2>/dev/null)

# Resolve the default branch. The `|| fallback` must guard the whole pipeline:
# `git ... | sed ... || echo main` never fires the fallback, because sed exits 0
# even when it produced no output.
DEFAULT_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)
DEFAULT_BRANCH=${DEFAULT_BRANCH#origin/}
if [ -z "$DEFAULT_BRANCH" ]; then
  for candidate in main master; do
    if git show-ref --verify --quiet "refs/remotes/origin/$candidate"; then
      DEFAULT_BRANCH="$candidate"
      break
    fi
  done
fi
[ -z "$DEFAULT_BRANCH" ] && emit_allow

# The deployed baseline is the REMOTE default branch: on a feature branch that is
# everything since main; on main itself it is the local commits not yet pushed.
BASE="origin/$DEFAULT_BRANCH"
git rev-parse --verify --quiet "$BASE" >/dev/null 2>&1 || emit_allow

if [ "$BRANCH" = "$DEFAULT_BRANCH" ]; then
  ENV_LABEL="PRODUCTION"
  CONVEX_CMD="/deploy (→ ./deploy-backend.sh)"
else
  ENV_LABEL="DEV"
  CONVEX_CMD="/deploy (→ ./deploy-backend-preview.sh)"
fi

WARNINGS=""

# ── Convex ──
if [ -d "$PROJECT_ROOT/convex" ]; then
  CONVEX_CHANGES=$(git diff "$BASE" --name-only 2>/dev/null \
    | grep '^convex/' | grep -v '_generated/' | grep -v '\.test\.')
  if [ -n "$CONVEX_CHANGES" ]; then
    COUNT=$(printf '%s\n' "$CONVEX_CHANGES" | wc -l | tr -d ' ')
    FILES=$(printf '%s\n' "$CONVEX_CHANGES" | head -5 | sed 's/^/  - /')
    WARNINGS="${WARNINGS}CONVEX: ${COUNT} file(s) changed → ${ENV_LABEL}
${FILES}
Deploy: ${CONVEX_CMD}

"
  fi
fi

# ── Modal ──
if [ -f "$PROJECT_ROOT/pyproject.toml" ] && grep -q "modal" "$PROJECT_ROOT/pyproject.toml" 2>/dev/null; then
  MODAL_CHANGES=$(git diff "$BASE" --name-only 2>/dev/null \
    | grep '\.py$' | grep -v 'test' | grep -v '__pycache__')
  if [ -n "$MODAL_CHANGES" ]; then
    COUNT=$(printf '%s\n' "$MODAL_CHANGES" | wc -l | tr -d ' ')
    WARNINGS="${WARNINGS}MODAL: ${COUNT} Python file(s) changed → ${ENV_LABEL}
Deploy: /deploy

"
  fi
fi

[ -z "$WARNINGS" ] && emit_allow

# Ask rather than allow: only the user knows whether the backend was already
# deployed. systemMessage surfaces the detail; permissionDecision "ask" is what
# actually stops the push from going out unnoticed.
MSG="${WARNINGS}Without a backend deploy the frontend will crash at runtime."
jq -n --arg m "$MSG" '{
  systemMessage: $m,
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "ask",
    permissionDecisionReason: $m
  }
}'
exit 0
