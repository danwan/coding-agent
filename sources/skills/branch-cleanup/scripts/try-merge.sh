#!/usr/bin/env bash
# try-merge.sh — attempt to bring <branch> up-to-date with default branch.
# Usage: try-merge.sh <branch> <strategy>
#   strategy: merge   — try `git merge default` (preserves history, reversible)
#             rebase  — try `git rebase default` (rewrites history; pushes with --force-with-lease)
#
# Honors DRYRUN=1.
#
# Exit codes:
#   0  CLEAN — operation completed (and pushed, if the branch has a live upstream)
#   1  hard error
#   10 RERERE_RESOLVED — rerere replayed cached resolutions; completed (and pushed)
#   20 REAL_CONFLICT — aborted, branch left untouched, user must resolve manually
#   30 LEASE_FAILED — completed locally but push was rejected (someone pushed in parallel)
#   3  DRYRUN echo
#
# Push policy: only pushes when the branch has a configured upstream that still
# exists. No upstream → local-only branch, publishing it is not this script's
# call. Upstream [gone] → remote deleted it, pushing would resurrect it.
# Both cases complete locally and say so.

set -euo pipefail

BRANCH="${1:-}"
STRATEGY="${2:-}"

if [[ -z "$BRANCH" || -z "$STRATEGY" ]]; then
  echo "Usage: try-merge.sh <branch> <merge|rebase>" >&2
  exit 1
fi

if [[ "$STRATEGY" != "merge" && "$STRATEGY" != "rebase" ]]; then
  echo "ERROR: strategy must be 'merge' or 'rebase'" >&2
  exit 1
fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "ERROR: not in a git repository" >&2
  exit 1
fi

if ! git rev-parse --verify "refs/heads/$BRANCH" >/dev/null 2>&1; then
  echo "ERROR: branch '$BRANCH' missing" >&2
  exit 1
fi

# Working tree must be clean
if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERROR: working tree dirty; commit or stash first" >&2
  exit 1
fi

# Default branch: gh → remote HEAD → main/master (same chain as audit.sh)
DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || true)
if [[ -z "$DEFAULT_BRANCH" ]]; then
  DEFAULT_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||' || true)
fi
if [[ -z "$DEFAULT_BRANCH" ]]; then
  if git rev-parse --verify refs/heads/main >/dev/null 2>&1; then DEFAULT_BRANCH=main
  elif git rev-parse --verify refs/heads/master >/dev/null 2>&1; then DEFAULT_BRANCH=master
  else echo "ERROR: cannot determine default branch" >&2; exit 1; fi
fi

# rerere must auto-STAGE replayed resolutions, not just write them to the
# working tree. Without autoupdate the index keeps the unmerged stages and the
# "did rerere resolve everything?" check below can never fire.
git config rerere.enabled true
git config rerere.autoupdate true

# Upstream state decides whether we push at the end.
UPSTREAM=$(git rev-parse --abbrev-ref "$BRANCH@{upstream}" 2>/dev/null || true)
PUSH_MODE="push"
if [[ -z "$UPSTREAM" ]]; then
  PUSH_MODE="skip_no_upstream"
elif ! git rev-parse --verify "$UPSTREAM" >/dev/null 2>&1; then
  PUSH_MODE="skip_upstream_gone"
fi

if [[ "${DRYRUN:-0}" == "1" ]]; then
  MSG="→ [DRYRUN] git switch $BRANCH && git $STRATEGY $DEFAULT_BRANCH"
  case "$PUSH_MODE" in
    push) [[ "$STRATEGY" == "rebase" ]] && MSG+=" && git push --force-with-lease" || MSG+=" && git push" ;;
    skip_no_upstream)   MSG+="  (no upstream — would not push)" ;;
    skip_upstream_gone) MSG+="  (upstream gone — would not push)" ;;
  esac
  echo "$MSG"
  exit 3
fi

# Snapshot original SHA + branch so we can recover and restore position
ORIG_SHA=$(git rev-parse "$BRANCH")
START_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
echo "→ snapshot: $BRANCH was at $ORIG_SHA (reflog will retain this)"

restore_start_branch() {
  if [[ -n "$START_BRANCH" && "$START_BRANCH" != "$BRANCH" ]]; then
    git switch --quiet "$START_BRANCH" 2>/dev/null || true
  fi
}

git switch "$BRANCH"

echo "→ git $STRATEGY $DEFAULT_BRANCH"
if [[ "$STRATEGY" == "merge" ]]; then
  if git merge --no-edit "$DEFAULT_BRANCH"; then
    OUTCOME="CLEAN"
  else
    OUTCOME="CONFLICT"
  fi
else
  if git rebase "$DEFAULT_BRANCH"; then
    OUTCOME="CLEAN"
  else
    OUTCOME="CONFLICT"
  fi
fi

if [[ "$OUTCOME" == "CONFLICT" ]]; then
  # With rerere.autoupdate on, fully-replayed resolutions leave zero unmerged paths.
  UNMERGED=$(git ls-files -u | wc -l | tr -d ' ')
  if [[ "$UNMERGED" -eq 0 ]]; then
    echo "→ rerere replayed cached resolutions"
    if [[ "$STRATEGY" == "merge" ]]; then
      git commit --no-edit
    else
      # Fail loud: a failed --continue means we're still mid-rebase.
      if ! GIT_EDITOR=true git rebase --continue; then
        echo "→ rebase --continue failed after rerere replay; aborting" >&2
        git rebase --abort
        restore_start_branch
        exit 20
      fi
    fi
    OUTCOME="RERERE_RESOLVED"
  else
    echo "→ unresolved conflicts in $UNMERGED path(s); aborting per safety policy"
    if [[ "$STRATEGY" == "merge" ]]; then git merge --abort; else git rebase --abort; fi
    restore_start_branch
    exit 20
  fi
fi

# Push (see policy in header)
case "$PUSH_MODE" in
  skip_no_upstream)
    echo "OK: $BRANCH updated locally (no upstream configured — not pushed)"
    restore_start_branch
    [[ "$OUTCOME" == "RERERE_RESOLVED" ]] && exit 10 || exit 0 ;;
  skip_upstream_gone)
    echo "OK: $BRANCH updated locally (upstream $UPSTREAM is gone — not pushed)"
    restore_start_branch
    [[ "$OUTCOME" == "RERERE_RESOLVED" ]] && exit 10 || exit 0 ;;
esac

PUSH_FLAGS=""
if [[ "$STRATEGY" == "rebase" ]]; then
  PUSH_FLAGS="--force-with-lease"
fi
echo "→ git push $PUSH_FLAGS"
if git push $PUSH_FLAGS; then
  echo "OK: $BRANCH updated and pushed"
  restore_start_branch
  [[ "$OUTCOME" == "RERERE_RESOLVED" ]] && exit 10 || exit 0
else
  echo "PUSH FAILED — likely someone else pushed in parallel. Branch was at $ORIG_SHA before; you can reset via: git reset --hard $ORIG_SHA"
  restore_start_branch
  exit 30
fi
