#!/bin/bash
# SessionStart hook: lightweight git status summary
# Outputs a systemMessage with repo state for context

# Check if we're in a git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    jq -n --arg msg "Not a git repository." '{systemMessage:$msg}'
    exit 0
fi

BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
STATUS=$(git status --porcelain 2>/dev/null)

MODIFIED=$(printf '%s\n' "$STATUS" | grep -c '^ M' 2>/dev/null)
STAGED=$(printf '%s\n' "$STATUS" | grep -c '^[MADR]' 2>/dev/null)
UNTRACKED=$(printf '%s\n' "$STATUS" | grep -c '^??' 2>/dev/null)

# Build summary
SUMMARY="Branch: $BRANCH"
[ "$MODIFIED" -gt 0 ] && SUMMARY="$SUMMARY | Modified: $MODIFIED"
[ "$STAGED" -gt 0 ] && SUMMARY="$SUMMARY | Staged: $STAGED"
[ "$UNTRACKED" -gt 0 ] && SUMMARY="$SUMMARY | Untracked: $UNTRACKED"

# Check if behind/ahead of remote (single git command instead of two)
UPSTREAM=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)
if [ -n "$UPSTREAM" ]; then
    COUNTS=$(git rev-list --left-right --count 'HEAD...@{upstream}' 2>/dev/null)
    if [ -n "$COUNTS" ]; then
        AHEAD=$(echo "$COUNTS" | cut -f1)
        BEHIND=$(echo "$COUNTS" | cut -f2)
        [ "$AHEAD" -gt 0 ] 2>/dev/null && SUMMARY="$SUMMARY | Ahead: $AHEAD"
        [ "$BEHIND" -gt 0 ] 2>/dev/null && SUMMARY="$SUMMARY | Behind: $BEHIND"
    fi
fi

jq -n --arg msg "$SUMMARY" '{systemMessage:$msg}'
