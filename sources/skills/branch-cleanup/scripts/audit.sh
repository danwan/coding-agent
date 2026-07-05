#!/usr/bin/env bash
# audit.sh — Phase 1 of branch-cleanup skill.
# Read-only audit of the current repo. Emits a structured block to stdout.
# Caller (Claude) parses key=value lines + START/END blocks.
#
# Env knobs:
#   STALE_DAYS  — age threshold for stale-by-time classification (default 90)

set -euo pipefail

# Must be inside a git repo
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "ERROR: not inside a git repository" >&2
  exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel)
REPO_NAME=$(basename "$REPO_ROOT")
cd "$REPO_ROOT"

STALE_DAYS="${STALE_DAYS:-90}"

# Primary remote: prefer "origin", else first configured remote, else none.
REMOTE=$( (git remote 2>/dev/null | grep -x origin) || (git remote 2>/dev/null | head -1) || true)

# Detect default branch. Fallback chain — never assume GitHub:
#   1. gh (authoritative when the repo is on GitHub and gh is authed)
#   2. the remote's HEAD symref (set on clone)
#   3. a local main/master ref
#   4. current branch (last resort, e.g. fresh local-only repo)
DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || true)
if [[ -z "$DEFAULT_BRANCH" && -n "$REMOTE" ]]; then
  DEFAULT_BRANCH=$(git symbolic-ref --short "refs/remotes/$REMOTE/HEAD" 2>/dev/null | sed "s|^$REMOTE/||" || true)
fi
if [[ -z "$DEFAULT_BRANCH" ]]; then
  if git rev-parse --verify refs/heads/main >/dev/null 2>&1; then DEFAULT_BRANCH=main
  elif git rev-parse --verify refs/heads/master >/dev/null 2>&1; then DEFAULT_BRANCH=master
  else DEFAULT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo main); fi
fi

# Refresh remote refs once. --prune drops stale tracking refs so [gone] detection is correct.
# Do NOT swallow a failed fetch: a blocked/failed fetch (sandbox SSH, network, auth) leaves every
# ref below stale, which silently corrupts merge/[gone]/behind classification. Capture and report it.
if [[ -z "$REMOTE" ]]; then
  FETCH_STATUS="NO_REMOTE"
elif FETCH_ERR=$(git fetch --all --prune --quiet 2>&1); then
  FETCH_STATUS="OK"
else
  FETCH_STATUS="FAILED: $(printf '%s' "$FETCH_ERR" | tr '\n' ' ' | cut -c1-200)"
fi

CURRENT=$(git symbolic-ref --short HEAD 2>/dev/null || echo "DETACHED")

# Working tree state
STAGED=$(git diff --cached --name-only | wc -l | tr -d ' ')
UNSTAGED=$(git diff --name-only | wc -l | tr -d ' ')
UNTRACKED=$(git ls-files --others --exclude-standard | wc -l | tr -d ' ')
STASH=$(git stash list | wc -l | tr -d ' ')
WORKTREE_STATE="CLEAN"
if [[ "$STAGED" -gt 0 || "$UNSTAGED" -gt 0 || "$UNTRACKED" -gt 0 ]]; then
  WORKTREE_STATE="DIRTY"
fi

echo "===AUDIT_START==="
echo "REPO_NAME=$REPO_NAME"
echo "REPO_ROOT=$REPO_ROOT"
echo "REMOTE=${REMOTE:-NONE}"
echo "DEFAULT_BRANCH=$DEFAULT_BRANCH"
echo "FETCH_STATUS=$FETCH_STATUS"
echo "CURRENT_BRANCH=$CURRENT"
echo "WORKTREE=$WORKTREE_STATE"
echo "STAGED=$STAGED"
echo "UNSTAGED=$UNSTAGED"
echo "UNTRACKED=$UNTRACKED"
echo "STASH=$STASH"

# Main vs remote main relationship
if [[ -n "$REMOTE" ]] && git rev-parse "$REMOTE/$DEFAULT_BRANCH" >/dev/null 2>&1; then
  MAIN_LOCAL=$(git rev-parse "$DEFAULT_BRANCH" 2>/dev/null || echo "MISSING")
  MAIN_REMOTE=$(git rev-parse "$REMOTE/$DEFAULT_BRANCH")
  if [[ "$MAIN_LOCAL" == "MISSING" ]]; then
    MAIN_STATE="LOCAL_MISSING"
  elif [[ "$MAIN_LOCAL" == "$MAIN_REMOTE" ]]; then
    MAIN_STATE="EQUAL"
  else
    AHEAD_MAIN=$(git rev-list --count "$REMOTE/$DEFAULT_BRANCH..$DEFAULT_BRANCH" 2>/dev/null || echo "0")
    BEHIND_MAIN=$(git rev-list --count "$DEFAULT_BRANCH..$REMOTE/$DEFAULT_BRANCH" 2>/dev/null || echo "0")
    if [[ "$AHEAD_MAIN" -gt 0 && "$BEHIND_MAIN" -gt 0 ]]; then
      MAIN_STATE="DIVERGED:ahead=$AHEAD_MAIN,behind=$BEHIND_MAIN"
    elif [[ "$AHEAD_MAIN" -gt 0 ]]; then
      MAIN_STATE="AHEAD:$AHEAD_MAIN"
    elif [[ "$BEHIND_MAIN" -gt 0 ]]; then
      MAIN_STATE="BEHIND:$BEHIND_MAIN"
    else
      MAIN_STATE="EQUAL"
    fi
  fi
else
  MAIN_STATE="NO_REMOTE_MAIN"
fi
echo "MAIN_STATE=$MAIN_STATE"

# Worktrees
echo "WORKTREES_START"
git worktree list --porcelain | awk '/^worktree /{path=$2} /^branch /{print path"|"substr($2,12)}'
echo "WORKTREES_END"

# Local branches with metadata
echo "BRANCHES_START"
NOW=$(date +%s)
# Format: name|tracking|ahead|behind|last_commit_unix|last_commit_iso|last_commit_subject
git for-each-ref --format='%(refname:short)|%(upstream:short)|%(upstream:track)|%(committerdate:unix)|%(committerdate:iso8601)|%(subject)' refs/heads | \
  while IFS='|' read -r BR UP TRACK CDATE_U CDATE_I SUBJ; do
    # Classify vs default branch
    if [[ "$BR" == "$DEFAULT_BRANCH" ]]; then
      CLASS="DEFAULT"
    else
      # Is BR fully merged into default?
      if git merge-base --is-ancestor "$BR" "$DEFAULT_BRANCH" 2>/dev/null; then
        CLASS="MERGED_INTO_DEFAULT"
      else
        # Compute ahead/behind vs default
        A=$(git rev-list --count "$DEFAULT_BRANCH..$BR" 2>/dev/null || echo 0)
        B=$(git rev-list --count "$BR..$DEFAULT_BRANCH" 2>/dev/null || echo 0)
        if [[ "$A" -gt 0 && "$B" -gt 0 ]]; then
          CLASS="DIVERGED_FROM_DEFAULT:ahead=$A,behind=$B"
        elif [[ "$A" -gt 0 ]]; then
          CLASS="AHEAD_OF_DEFAULT:$A"
        elif [[ "$B" -gt 0 ]]; then
          CLASS="BEHIND_DEFAULT:$B"
        else
          CLASS="EQUAL_TO_DEFAULT"
        fi
      fi
    fi
    # Detect [gone] tracking
    GONE="false"
    if [[ -n "$UP" ]]; then
      if ! git rev-parse "$UP" >/dev/null 2>&1; then
        GONE="true"
      fi
    fi
    # Stale-by-time: no commit in STALE_DAYS days (guard empty date → treat as fresh)
    AGE_DAYS=$(( (NOW - ${CDATE_U:-$NOW}) / 86400 ))
    STALE="false"
    if [[ "$AGE_DAYS" -gt "$STALE_DAYS" ]]; then
      STALE="true"
    fi
    # Squash-detect: if cherry says no unique commits → safe to delete despite "not merged"
    SQUASHED="false"
    if [[ "$CLASS" != "DEFAULT" && "$CLASS" != "MERGED_INTO_DEFAULT" ]]; then
      if [[ -z "$(git cherry "$DEFAULT_BRANCH" "$BR" 2>/dev/null | grep '^+')" ]]; then
        SQUASHED="true"
      fi
    fi
    echo "BRANCH|name=$BR|upstream=$UP|track=$TRACK|class=$CLASS|gone=$GONE|stale=$STALE|squashed=$SQUASHED|age_days=$AGE_DAYS|last_commit=$CDATE_I|subject=$SUBJ"
  done
echo "BRANCHES_END"

# Remote branches not present locally
echo "REMOTE_ONLY_START"
if [[ -n "$REMOTE" ]]; then
  git for-each-ref --format='%(refname:short)' "refs/remotes/$REMOTE" | \
    awk -v r="$REMOTE" '$0 != r && $0 != r"/HEAD" {sub("^"r"/",""); print}' | \
    while read -r RB; do
      if ! git rev-parse --verify "refs/heads/$RB" >/dev/null 2>&1; then
        AGE=$(git log -1 --format='%cr' "$REMOTE/$RB" 2>/dev/null || echo "unknown")
        echo "REMOTE_ONLY|name=$RB|age=$AGE"
      fi
    done
fi
echo "REMOTE_ONLY_END"

# Open PRs — GitHub-only section. Degrade loudly, not silently:
# GH_STATE tells the caller WHY PR data is absent so it can skip PR phases with a clear message.
echo "PRS_START"
if ! command -v gh >/dev/null 2>&1; then
  echo "GH_STATE=NO_GH_CLI"
else
  PR_TMP="${TMPDIR:-/tmp}/branch-cleanup-prs-$$.json"
  if GH_ERR=$(gh pr list --state open --limit 100 \
      --json number,title,headRefName,isDraft,mergeable,mergeStateStatus,reviewDecision,statusCheckRollup,url \
      2>&1 >"$PR_TMP"); then
    echo "GH_STATE=OK"
    python3 - "$PR_TMP" <<'PYEOF' || echo "PR_ERROR=parse_failed"
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
print(f"PR_COUNT={len(data)}")
if len(data) >= 100:
    print("PR_TRUNCATED=true")  # more open PRs may exist than were fetched
for pr in data:
    checks = pr.get('statusCheckRollup') or []
    failing = [c for c in checks if (c.get('conclusion') in ('FAILURE','CANCELLED','TIMED_OUT') or c.get('state') == 'FAILURE')]
    pending = [c for c in checks if (c.get('status') in ('IN_PROGRESS','QUEUED','PENDING') or c.get('state') == 'PENDING')]
    # gh returns "" (not null) for reviewDecision when no review is required — normalize.
    review = pr.get('reviewDecision') or None
    mergeable = pr.get('mergeable')
    if pr['isDraft']:
        cat = 'DRAFT'
    elif mergeable == 'CONFLICTING':
        cat = 'BLOCKED_CONFLICT'
    elif mergeable == 'UNKNOWN':
        cat = 'UNKNOWN_MERGEABILITY'  # GitHub still computing — re-query at execute time
    elif failing:
        cat = 'BLOCKED_CI'
    elif pending:
        cat = 'PENDING_CI'
    elif review not in ('APPROVED', None):
        cat = 'BLOCKED_REVIEW'
    elif review is None:
        cat = 'MERGEABLE_NO_REVIEW'
    elif mergeable == 'MERGEABLE':
        cat = 'MERGEABLE_GREEN'
    else:
        cat = 'OTHER'
    failing_names = ','.join((c.get('name') or c.get('context') or '?') for c in failing) or '-'
    n = pr['number']; h = pr['headRefName']
    s = pr['mergeStateStatus']; u = pr['url']; t = pr['title']
    print(f"PR|number={n}|head={h}|cat={cat}|review={review}|merge={mergeable}|state={s}|failing={failing_names}|url={u}|title={t}")
PYEOF
  else
    # Classify the gh failure so the caller can present it honestly.
    ERR_SHORT=$(printf '%s' "$GH_ERR" | tr '\n' ' ' | cut -c1-160)
    # Order matters: the "no GitHub host" message also mentions `gh auth login`,
    # but the real cause is the absence of a GitHub remote, so match it first.
    case "$GH_ERR" in
      *"no git remotes"*|*"no GitHub remotes"*|*"known GitHub host"*|*"could not determine base repo"*|*"unsupported host"*|*"not a GitHub repository"*)
        echo "GH_STATE=NO_GITHUB_REMOTE" ;;
      *"gh auth login"*|*"authentication"*|*"HTTP 401"*|*"HTTP 403"*|*"not logged"*)
        echo "GH_STATE=NOT_AUTHENTICATED" ;;
      *)
        echo "GH_STATE=ERROR" ;;
    esac
    echo "GH_ERROR=$ERR_SHORT"
  fi
  rm -f "$PR_TMP"
fi
echo "PRS_END"

# Failing CI excerpts (only for blocked-by-ci PRs; cap at 20 lines per failure)
echo "CI_LOGS_START"
if command -v gh >/dev/null 2>&1; then
  CI_TMP="${TMPDIR:-/tmp}/branch-cleanup-ci-$$.json"
  if gh pr list --state open --limit 100 --json number,statusCheckRollup > "$CI_TMP" 2>/dev/null; then
    python3 - "$CI_TMP" <<'PYEOF' || true
import json, sys, subprocess
with open(sys.argv[1]) as f:
    data = json.load(f)
for pr in data:
    checks = pr.get('statusCheckRollup') or []
    failing = [c for c in checks if (c.get('conclusion') in ('FAILURE','CANCELLED','TIMED_OUT'))]
    if not failing:
        continue
    n = pr['number']
    print(f"---PR_{n}_FAILING_CI---")
    for fjob in failing[:3]:
        name = fjob.get('name') or fjob.get('context') or '?'
        print(f"---JOB:{name}---")
        run_id = fjob.get('detailsUrl','').rsplit('/',1)[-1] if fjob.get('detailsUrl') else None
        if run_id and run_id.isdigit():
            try:
                out = subprocess.run(['gh','run','view',run_id,'--log-failed'], capture_output=True, text=True, timeout=15)
                lines = (out.stdout or out.stderr).splitlines()
                idx = 0
                for i, l in enumerate(lines):
                    if any(k in l.lower() for k in ['error','fail','fatal','traceback']):
                        idx = max(0, i-2); break
                for l in lines[idx:idx+20]:
                    print(l)
            except Exception as e:
                print(f"(could not fetch log: {e})")
        else:
            print("(no run id available)")
PYEOF
  fi
  rm -f "$CI_TMP"
fi
echo "CI_LOGS_END"

echo "===AUDIT_END==="
