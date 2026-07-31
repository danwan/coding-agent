#!/usr/bin/env bash
# safe-delete.sh — delete a local branch with safety gates.
# Usage: safe-delete.sh <branch> [--force-squashed] [--with-remote]
#   --force-squashed: allow `-D` only when audit classified the branch as squash-merged
#                     (i.e. `git cherry default branch` shows no unique commits)
#   --with-remote:    after a successful local delete, also delete the branch's
#                     live upstream (git push <remote> --delete <ref>). Skips
#                     remote deletion with a note when there is no upstream or
#                     it is already gone — never resurrects or guesses a remote.
#
# Honors DRYRUN=1 in the env (echoes instead of executing).
# Refuses to delete the currently checked-out branch.
# Refuses if the branch is checked out in another worktree (reports the path).
# Returns:
#   0 on success
#   1 on hard error (bad args, not a repo, branch missing)
#   2 on safety refusal (worktree blocking, unmerged work, unverifiable squash check)
#   3 on dry-run echo (no real action taken)
#   4 local branch deleted, but the --with-remote remote delete failed

set -euo pipefail

BRANCH="${1:-}"
FORCE_SQUASHED="false"
WITH_REMOTE="false"
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force-squashed) FORCE_SQUASHED="true"; shift ;;
    --with-remote) WITH_REMOTE="true"; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$BRANCH" ]]; then
  echo "Usage: safe-delete.sh <branch> [--force-squashed] [--with-remote]" >&2
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

# Worktree check — if branch is checked out in another worktree, fail with details.
# substr($0,10) keeps worktree paths with spaces intact ("worktree " is 9 chars).
WORKTREE_PATH=$(git worktree list --porcelain | awk -v br="$BRANCH" '
  /^worktree /{p=substr($0,10)}
  /^branch /{ if (substr($2,12) == br) print p }
' | head -1)

if [[ -n "$WORKTREE_PATH" ]]; then
  echo "REFUSED: branch '$BRANCH' is checked out in worktree at: $WORKTREE_PATH" >&2
  echo "  Remove the worktree first: git worktree remove $WORKTREE_PATH" >&2
  exit 2
fi

# Capture commit hash for recovery
SHA=$(git rev-parse "$BRANCH")

# Capture the upstream BEFORE deleting — `git branch -d/-D` removes the
# branch's config section, so this is unreadable afterwards.
UPSTREAM_REMOTE=$(git config "branch.$BRANCH.remote" 2>/dev/null || true)
UPSTREAM_REF=$(git config "branch.$BRANCH.merge" 2>/dev/null | sed 's|^refs/heads/||' || true)
REMOTE_LIVE="false"
if [[ -n "$UPSTREAM_REMOTE" && -n "$UPSTREAM_REF" ]] && \
   git rev-parse --verify "refs/remotes/$UPSTREAM_REMOTE/$UPSTREAM_REF" >/dev/null 2>&1; then
  REMOTE_LIVE="true"
fi

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
  # The squash check compares against the default branch. If that ref does not
  # actually resolve, `git cherry` fails — and a swallowed failure would look
  # exactly like "no unique commits" and green-light -D on unmerged work.
  # A guard that cannot fire looks like a guard that found nothing: refuse.
  if ! git rev-parse --verify --quiet "${DEFAULT_BRANCH}^{commit}" >/dev/null; then
    echo "REFUSED: default branch '$DEFAULT_BRANCH' does not resolve to a commit — cannot verify squash-merge" >&2
    exit 2
  fi
  if ! CHERRY_OUT=$(git cherry "$DEFAULT_BRANCH" "$BRANCH" 2>&1); then
    echo "REFUSED: git cherry failed — cannot verify squash-merge: $CHERRY_OUT" >&2
    exit 2
  fi
  if ! printf '%s\n' "$CHERRY_OUT" | grep -q '^+'; then
    DEL_FLAG="-D"
    echo "→ Squash-merge confirmed (no unique commits vs $DEFAULT_BRANCH); using -D"
  else
    echo "REFUSED: --force-squashed passed but branch has unique commits vs default" >&2
    exit 2
  fi
fi

if [[ "${DRYRUN:-0}" == "1" ]]; then
  echo "→ [DRYRUN] git branch $DEL_FLAG $BRANCH  (was at $SHA)"
  if [[ "$WITH_REMOTE" == "true" ]]; then
    if [[ "$REMOTE_LIVE" == "true" ]]; then
      echo "→ [DRYRUN] git push $UPSTREAM_REMOTE --delete $UPSTREAM_REF"
    else
      echo "→ [DRYRUN] (--with-remote: no live upstream — nothing to delete remotely)"
    fi
  fi
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

if [[ "$WITH_REMOTE" == "true" ]]; then
  if [[ "$REMOTE_LIVE" == "true" ]]; then
    echo "→ git push $UPSTREAM_REMOTE --delete $UPSTREAM_REF"
    if git push "$UPSTREAM_REMOTE" --delete "$UPSTREAM_REF"; then
      echo "OK: deleted remote branch $UPSTREAM_REMOTE/$UPSTREAM_REF"
    else
      echo "WARN: local branch deleted but remote delete FAILED for $UPSTREAM_REMOTE/$UPSTREAM_REF — reconcile manually" >&2
      exit 4
    fi
  else
    echo "NOTE: --with-remote requested but '$BRANCH' has no live upstream — nothing to delete remotely"
  fi
fi
