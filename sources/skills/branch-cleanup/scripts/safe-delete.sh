#!/usr/bin/env bash
# safe-delete.sh — delete a local branch with safety gates.
# Usage: safe-delete.sh <branch> [--force-squashed]
#   --force-squashed: allow `-D` only when audit classified the branch as squash-merged
#                     (i.e. `git cherry default branch` shows no unique commits)
#
# Honors DRYRUN=1 in the env (echoes instead of executing).
# Refuses to delete the currently checked-out branch.
# Refuses if the branch is checked out in another worktree (reports the path).
# Returns:
#   0 on success
#   1 on hard error (bad args, not a repo, branch missing)
#   2 on safety refusal (worktree blocking, unmerged work)
#   3 on dry-run echo (no real action taken)

set -euo pipefail

BRANCH="${1:-}"
FORCE_SQUASHED="false"
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force-squashed) FORCE_SQUASHED="true"; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$BRANCH" ]]; then
  echo "Usage: safe-delete.sh <branch> [--force-squashed]" >&2
  exit 1
fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "ERROR: not in a git repository" >&2
  exit 1
fi

if ! git rev-parse --verify "refs/heads/$BRANCH" >/dev/null 2>&1; then
  echo "ERROR: branch '$BRANCH' does not exist" >&2
  exit 1
fi

CURRENT=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
if [[ "$CURRENT" == "$BRANCH" ]]; then
  echo "ERROR: refusing to delete currently checked-out branch '$BRANCH'" >&2
  exit 2
fi

# Worktree check — if branch is checked out in another worktree, fail with details
WORKTREE_PATH=$(git worktree list --porcelain | awk -v br="$BRANCH" '
  /^worktree /{p=$2}
  /^branch /{ if (substr($2,12) == br) print p }
' | head -1)

if [[ -n "$WORKTREE_PATH" ]]; then
  echo "REFUSED: branch '$BRANCH' is checked out in worktree at: $WORKTREE_PATH" >&2
  echo "  Remove the worktree first: git worktree remove $WORKTREE_PATH" >&2
  exit 2
fi

# Capture commit hash for recovery
SHA=$(git rev-parse "$BRANCH")

# Default branch: gh → remote HEAD → main/master (same chain as audit.sh)
DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || true)
if [[ -z "$DEFAULT_BRANCH" ]]; then
  DEFAULT_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||' || true)
fi
if [[ -z "$DEFAULT_BRANCH" ]]; then
  if git rev-parse --verify refs/heads/master >/dev/null 2>&1 && \
     ! git rev-parse --verify refs/heads/main >/dev/null 2>&1; then DEFAULT_BRANCH=master
  else DEFAULT_BRANCH=main; fi
fi

# Choose -d vs -D
DEL_FLAG="-d"
if [[ "$FORCE_SQUASHED" == "true" ]]; then
  # Re-verify squash-merge property at exec time
  if [[ -z "$(git cherry "$DEFAULT_BRANCH" "$BRANCH" 2>/dev/null | grep '^+')" ]]; then
    DEL_FLAG="-D"
    echo "→ Squash-merge confirmed (no unique commits vs $DEFAULT_BRANCH); using -D"
  else
    echo "REFUSED: --force-squashed passed but branch has unique commits vs default" >&2
    exit 2
  fi
fi

if [[ "${DRYRUN:-0}" == "1" ]]; then
  echo "→ [DRYRUN] git branch $DEL_FLAG $BRANCH  (was at $SHA)"
  exit 3
fi

echo "→ git branch $DEL_FLAG $BRANCH  (was at $SHA — recoverable via git reflog or 'git branch $BRANCH $SHA')"
# -d judges "merged" against HEAD/upstream — an unmerged branch makes git exit
# non-zero. That's a safety refusal (exit 2 per header), not a hard error.
if ! git branch "$DEL_FLAG" "$BRANCH"; then
  echo "REFUSED: git considers '$BRANCH' not fully merged. If audit marked it squashed, re-run with --force-squashed; otherwise merge or inspect it first." >&2
  exit 2
fi
echo "OK: deleted $BRANCH (was $SHA)"
