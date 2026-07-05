#!/bin/bash
set -uo pipefail

# git-sync.sh — Multi-machine git repo synchronization tool
# Produces structured, parseable output for consumption by Claude Skills.
# SAFETY: Never force-pushes, never runs destructive commands.

readonly VERSION="1.0.0"

##############################################################################
# Helpers
##############################################################################

die() {
  echo "ERROR: $*" >&2
  exit 1
}

action_output() {
  local cmd="$1" repo="$2" result="$3" message="$4"
  echo "===ACTION=== ${cmd} ${repo}"
  echo "RESULT=${result}"
  echo "MESSAGE=${message}"
}

# Portable timeout: use GNU timeout, gtimeout (macOS Homebrew), or fallback
_timeout() {
  local secs="$1"
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$secs" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$secs" "$@"
  else
    # Fallback: run without timeout
    "$@"
  fi
}

# Resolve to absolute path
resolve_path() {
  local p="$1"
  if [[ "$p" = /* ]]; then
    echo "$p"
  else
    echo "${PWD}/${p}"
  fi
}

# Resolve the ref to compare branches against. Prefers the REMOTE default
# branch — right after a fetch the local main is often stale, which would
# misclassify remote branches. Falls back to local main/master.
resolve_default_ref() {
  local repo="$1"
  local head_ref
  if head_ref="$(git -C "$repo" symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null)"; then
    echo "${head_ref#refs/remotes/}"
    return 0
  fi
  local ref
  for ref in origin/main origin/master main master; do
    if git -C "$repo" rev-parse --verify --quiet "$ref" >/dev/null 2>&1; then
      echo "$ref"
      return 0
    fi
  done
  return 1
}

##############################################################################
# audit_repo — gather all status info for a single repo
##############################################################################

audit_repo() {
  local repo_path="$1"
  local no_fetch="${2:-0}"
  local repo_name
  repo_name="$(basename "$repo_path")"

  # Validate git repo
  if ! git -C "$repo_path" rev-parse --git-dir >/dev/null 2>&1; then
    return
  fi

  echo "===REPO_START=== ${repo_name}"

  # Current branch (detect detached HEAD)
  local branch
  branch="$(git -C "$repo_path" symbolic-ref --short HEAD 2>/dev/null)" || branch="DETACHED"
  echo "BRANCH=${branch}"

  # Remote URL (origin)
  local remote_url
  remote_url="$(git -C "$repo_path" remote get-url origin 2>/dev/null)" || remote_url="NONE"
  echo "REMOTE_URL=${remote_url}"

  # Fetch with timeout. SKIPPED = no remote or --no-fetch (e.g. after fetch-all)
  local fetch_status="OK"
  if [[ "$remote_url" == "NONE" || "$no_fetch" == "1" ]]; then
    fetch_status="SKIPPED"
  elif ! _timeout 10 git -C "$repo_path" fetch --quiet 2>/dev/null; then
    fetch_status="FAILED"
  fi
  echo "FETCH=${fetch_status}"

  # Local branch count
  local local_branches
  local_branches="$(git -C "$repo_path" branch --list | wc -l | tr -d ' ')"
  echo "LOCAL_BRANCHES=${local_branches}"

  # Remote branch count (exclude HEAD)
  local remote_branches
  remote_branches="$(git -C "$repo_path" branch -r --list 2>/dev/null | grep -v '/HEAD' | wc -l | tr -d ' ')"
  echo "REMOTE_BRANCHES=${remote_branches}"

  # Staged / unstaged / untracked counts from porcelain status
  local staged=0 unstaged=0 untracked=0
  local untracked_files=()

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local x="${line:0:1}"
    local y="${line:1:1}"
    local file="${line:3}"

    if [[ "$x" == "?" ]]; then
      untracked=$((untracked + 1))
      untracked_files+=("$file")
      continue
    fi

    # Staged: index has changes (not ' ' or '?')
    if [[ "$x" != " " && "$x" != "?" ]]; then
      staged=$((staged + 1))
    fi

    # Unstaged: worktree has changes (not ' ' or '?')
    if [[ "$y" != " " && "$y" != "?" ]]; then
      unstaged=$((unstaged + 1))
    fi
  done < <(git -C "$repo_path" status --porcelain 2>/dev/null)

  echo "STAGED=${staged}"
  echo "UNSTAGED=${unstaged}"
  echo "UNTRACKED=${untracked}"

  # Ahead / behind / diverged
  local ahead=0 behind=0 diverged="UNKNOWN"
  if [[ "$branch" != "DETACHED" ]]; then
    local upstream
    upstream="$(git -C "$repo_path" rev-parse --abbrev-ref "${branch}@{upstream}" 2>/dev/null)" || upstream=""
    if [[ -n "$upstream" ]]; then
      local ab
      ab="$(git -C "$repo_path" rev-list --left-right --count "${branch}...${upstream}" 2>/dev/null)" || ab=""
      if [[ -n "$ab" ]]; then
        ahead="$(echo "$ab" | awk '{print $1}')"
        behind="$(echo "$ab" | awk '{print $2}')"
        if [[ "$ahead" -gt 0 && "$behind" -gt 0 ]]; then
          diverged="YES"
        else
          diverged="NO"
        fi
      fi
    fi
  fi
  echo "AHEAD=${ahead}"
  echo "BEHIND=${behind}"
  echo "DIVERGED=${diverged}"

  # Stash count
  local stash_count
  stash_count="$(git -C "$repo_path" stash list 2>/dev/null | wc -l | tr -d ' ')"
  echo "STASH=${stash_count}"

  # Worktree status
  if [[ "$staged" -eq 0 && "$unstaged" -eq 0 && "$untracked" -eq 0 ]]; then
    echo "WORKTREE=CLEAN"
  else
    echo "WORKTREE=DIRTY"
  fi

  # Tracking info block (always shown)
  echo "TRACKING_START"
  while IFS= read -r ref_line; do
    [[ -z "$ref_line" ]] && continue
    echo "$ref_line"
  done < <(git -C "$repo_path" for-each-ref --format='%(refname:short) %(upstream:short) %(upstream:track)' refs/heads/ 2>/dev/null | while IFS= read -r fl; do
    local bname upstream_name track_info
    bname="$(echo "$fl" | awk '{print $1}')"
    upstream_name="$(echo "$fl" | awk '{print $2}')"
    # track_info is everything after the second field
    track_info="$(echo "$fl" | awk '{$1=""; $2=""; sub(/^  /, ""); print}')"

    if [[ -z "$upstream_name" ]]; then
      # No upstream — check if upstream was set but is gone
      local raw_upstream
      raw_upstream="$(git -C "$repo_path" config "branch.${bname}.merge" 2>/dev/null)" || raw_upstream=""
      if [[ -n "$raw_upstream" ]]; then
        echo "${bname}  [gone]"
      else
        echo "${bname}  [no upstream]"
      fi
    else
      if [[ -n "$track_info" ]]; then
        echo "${bname} ${upstream_name} ${track_info}"
      else
        echo "${bname} ${upstream_name}"
      fi
    fi
  done)
  echo "TRACKING_END"

  # Untracked files block (only if count > 0)
  if [[ "$untracked" -gt 0 ]]; then
    echo "UNTRACKED_FILES_START"
    for f in "${untracked_files[@]}"; do
      echo "$f"
    done
    echo "UNTRACKED_FILES_END"
  fi

  # Remote-only branches (exist on remote but not locally)
  if [[ "$remote_url" != "NONE" && "$fetch_status" != "FAILED" ]]; then
    # Compare against the remote default branch (local main may be stale)
    local default_ref
    default_ref="$(resolve_default_ref "$repo_path")" || default_ref=""

    local remote_only_count=0
    local remote_only_lines=()

    # Collect local branch names into an associative-style list
    local local_branch_list
    local_branch_list="$(git -C "$repo_path" branch --list --format='%(refname:short)' 2>/dev/null)"

    while IFS= read -r remote_ref; do
      [[ -z "$remote_ref" ]] && continue
      # Strip leading whitespace
      remote_ref="$(echo "$remote_ref" | sed 's/^[[:space:]]*//')"
      # Skip HEAD pointer
      [[ "$remote_ref" == *"/HEAD" ]] && continue
      [[ "$remote_ref" == *"HEAD ->"* ]] && continue

      # Extract the branch name without remote prefix (e.g., origin/feature → feature)
      local short_name="${remote_ref#origin/}"

      # Check if a local branch with this name exists
      local is_local=false
      while IFS= read -r lb; do
        [[ -z "$lb" ]] && continue
        if [[ "$lb" == "$short_name" ]]; then
          is_local=true
          break
        fi
      done <<< "$local_branch_list"

      if [[ "$is_local" == "true" ]]; then
        continue
      fi

      # This is a remote-only branch
      remote_only_count=$((remote_only_count + 1))

      # Gather info about this remote-only branch
      local ro_date ro_subject ro_relationship ro_diffstat ro_base_info

      ro_date="$(git -C "$repo_path" log -1 --format=%cs "$remote_ref" 2>/dev/null)" || ro_date="unknown"
      ro_subject="$(git -C "$repo_path" log -1 --format=%s "$remote_ref" 2>/dev/null)" || ro_subject="unknown"

      # Relationship to default branch
      ro_relationship="UNKNOWN"
      ro_base_info="unknown"
      local merge_base default_head=""
      if [[ -n "$default_ref" ]]; then
        default_head="$(git -C "$repo_path" rev-parse "$default_ref" 2>/dev/null)" || default_head=""
      fi

      if [[ -n "$default_head" ]]; then
        merge_base="$(git -C "$repo_path" merge-base "$remote_ref" "$default_ref" 2>/dev/null)" || merge_base=""

        if [[ -n "$merge_base" ]]; then
          ro_base_info="based_on:${merge_base:0:8}"

          if [[ "$merge_base" == "$default_head" ]]; then
            # merge-base is at default branch HEAD — branch builds on latest
            local ro_branch_head
            ro_branch_head="$(git -C "$repo_path" rev-parse "$remote_ref" 2>/dev/null)" || ro_branch_head=""
            if [[ "$ro_branch_head" == "$default_head" ]]; then
              ro_relationship="SAME_AS_MAIN"
            else
              ro_relationship="AHEAD_OF_MAIN"
            fi
          else
            # merge-base is behind default branch — check if branch has own commits
            local ro_own_commits
            ro_own_commits="$(git -C "$repo_path" rev-list --count "${merge_base}..${remote_ref}" 2>/dev/null)" || ro_own_commits="0"
            if [[ "$ro_own_commits" -gt 0 ]]; then
              ro_relationship="DIVERGED_FROM_MAIN"
            else
              ro_relationship="BEHIND_MAIN"
            fi
          fi

          # Also check if based on a local feature branch (not default)
          while IFS= read -r lb; do
            [[ -z "$lb" ]] && continue
            local lb_head
            lb_head="$(git -C "$repo_path" rev-parse "refs/heads/${lb}" 2>/dev/null)" || continue
            # Skip branches already contained in the default branch — they would
            # match every branch built on main (false BASED_ON positives)
            if [[ -n "$default_head" ]] && git -C "$repo_path" merge-base --is-ancestor "$lb_head" "$default_head" 2>/dev/null; then
              continue
            fi
            local lb_merge_base
            lb_merge_base="$(git -C "$repo_path" merge-base "$remote_ref" "refs/heads/${lb}" 2>/dev/null)" || continue
            if [[ "$lb_merge_base" == "$lb_head" ]]; then
              ro_relationship="BASED_ON:${lb}"
              ro_base_info="based_on:${lb}"
              break
            fi
          done <<< "$local_branch_list"
        fi
      fi

      # Diff stat against merge-base
      ro_diffstat="+0/-0"
      if [[ -n "${merge_base:-}" ]]; then
        local stat_line
        stat_line="$(git -C "$repo_path" diff --shortstat "${merge_base}..${remote_ref}" 2>/dev/null)" || stat_line=""
        if [[ -n "$stat_line" ]]; then
          local insertions deletions
          insertions="$(echo "$stat_line" | grep -o '[0-9]* insertion' | grep -o '[0-9]*')" || insertions="0"
          deletions="$(echo "$stat_line" | grep -o '[0-9]* deletion' | grep -o '[0-9]*')" || deletions="0"
          [[ -z "$insertions" ]] && insertions="0"
          [[ -z "$deletions" ]] && deletions="0"
          ro_diffstat="+${insertions}/-${deletions}"
        fi
      fi

      remote_only_lines+=("${remote_ref}|${ro_date}|${ro_subject}|${ro_relationship}|${ro_diffstat}|${ro_base_info}")
    done < <(git -C "$repo_path" branch -r --list 2>/dev/null)

    echo "REMOTE_ONLY=${remote_only_count}"
    if [[ "$remote_only_count" -gt 0 ]]; then
      echo "REMOTE_ONLY_START"
      for ro_line in "${remote_only_lines[@]}"; do
        echo "$ro_line"
      done
      echo "REMOTE_ONLY_END"
    fi
  else
    echo "REMOTE_ONLY=0"
  fi

  # Open PRs (optional, requires gh CLI)
  if [[ "$remote_url" != "NONE" ]] && command -v gh >/dev/null 2>&1; then
    local pr_json
    if pr_json="$(cd "$repo_path" && _timeout 5 gh pr list --json number,title,headRefName,updatedAt --limit 50 2>/dev/null)"; then
      local pr_count
      if command -v jq >/dev/null 2>&1; then
        pr_count="$(printf '%s' "$pr_json" | jq 'length' 2>/dev/null)" || pr_count="0"
      else
        pr_count="$(printf '%s' "$pr_json" | python3 -c 'import sys,json;print(len(json.load(sys.stdin)))' 2>/dev/null)" || pr_count="0"
      fi
      [[ "$pr_count" =~ ^[0-9]+$ ]] || pr_count="0"
      echo "OPEN_PRS=${pr_count}"
      if [[ "$pr_count" -gt 0 ]]; then
        echo "OPEN_PRS_START"
        # Parse JSON line by line — extract fields with lightweight parsing
        echo "$pr_json" | python3 -c "
import sys, json
try:
    prs = json.load(sys.stdin)
    for pr in prs:
        num = pr.get('number', '?')
        title = pr.get('title', '').replace('|', '-')
        branch = pr.get('headRefName', '?')
        updated = pr.get('updatedAt', '?')[:10]
        print(f'#{num}|{title}|{branch}|{updated}')
except:
    pass
" 2>/dev/null || true
        echo "OPEN_PRS_END"
      fi
    else
      echo "OPEN_PRS=UNAVAILABLE"
    fi
  else
    echo "OPEN_PRS=UNAVAILABLE"
  fi

  echo "===REPO_END==="
}

##############################################################################
# Commands
##############################################################################

cmd_audit() {
  local dir="" no_fetch=0 a
  for a in "$@"; do
    case "$a" in
      --no-fetch) no_fetch=1 ;;
      *) dir="$a" ;;
    esac
  done
  dir="${dir:-$PWD}"
  dir="$(resolve_path "$dir")"

  if [[ ! -d "$dir" ]]; then
    die "Directory not found: ${dir}"
  fi

  # Only subdirectories are scanned — flag it if the target dir is itself a repo
  local toplevel phys
  toplevel="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || toplevel=""
  phys="$(cd "$dir" 2>/dev/null && pwd -P)" || phys=""
  if [[ -n "$toplevel" && "$toplevel" == "$phys" ]]; then
    echo "NOTE=Target directory is itself a git repo; it is NOT audited (only subdirectories are)"
  fi

  for entry in "$dir"/*/; do
    [[ ! -d "$entry" ]] && continue
    local name
    name="$(basename "$entry")"
    # Skip hidden directories
    [[ "$name" == .* ]] && continue
    # Must be a git repo
    if git -C "$entry" rev-parse --git-dir >/dev/null 2>&1; then
      audit_repo "$entry" "$no_fetch" || true
    fi
  done
}

cmd_fetch_all() {
  local dir="${1:-$PWD}"
  dir="$(resolve_path "$dir")"

  if [[ ! -d "$dir" ]]; then
    die "Directory not found: ${dir}"
  fi

  # Fetches are network-bound — run up to 8 in parallel. Each job emits its
  # whole ACTION block via a single printf (atomic on pipes <4KB), so blocks
  # stay intact even with interleaved job completion.
  for entry in "$dir"/*/; do
    [[ ! -d "$entry" ]] && continue
    local name
    name="$(basename "$entry")"
    [[ "$name" == .* ]] && continue
    git -C "$entry" rev-parse --git-dir >/dev/null 2>&1 || continue
    if ! git -C "$entry" remote get-url origin >/dev/null 2>&1; then
      action_output "fetch" "$name" "SKIPPED" "No remote configured"
      continue
    fi

    (
      local out
      if _timeout 10 git -C "$entry" fetch --quiet 2>/dev/null; then
        out="$(action_output "fetch" "$name" "OK" "Fetched successfully")"
      else
        out="$(action_output "fetch" "$name" "FAILED" "Fetch failed or timed out")"
      fi
      printf '%s\n' "$out"
    ) &
    if (( $(jobs -rp | wc -l) >= 8 )); then
      # wait -n needs bash 4.3+; macOS /bin/bash 3.2 falls back to full wait
      wait -n 2>/dev/null || wait
    fi
  done
  wait
}

cmd_pull() {
  local repo="${1:?pull requires a repo path}"
  repo="$(resolve_path "$repo")"
  local name
  name="$(basename "$repo")"

  if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
    action_output "pull" "$name" "FAILED" "Not a git repository"
    return 1
  fi

  local output
  if output="$(git -C "$repo" pull --ff-only 2>&1)"; then
    action_output "pull" "$name" "OK" "$output"
  else
    if echo "$output" | grep -qi "diverge\|not possible to fast-forward\|fatal.*not possible"; then
      action_output "pull" "$name" "FAILED" "DIVERGED: Fast-forward not possible. Manual merge required."
    else
      action_output "pull" "$name" "FAILED" "$output"
    fi
  fi
}

cmd_push() {
  local repo="${1:?push requires a repo path}"
  repo="$(resolve_path "$repo")"
  local name
  name="$(basename "$repo")"

  # SAFETY: always runs a plain `git push` — no flags are ever forwarded,
  # so force-pushing through this script is impossible by construction.
  if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
    action_output "push" "$name" "FAILED" "Not a git repository"
    return 1
  fi

  local output
  if output="$(git -C "$repo" push 2>&1)"; then
    action_output "push" "$name" "OK" "${output:-Pushed successfully}"
  else
    action_output "push" "$name" "FAILED" "$output"
  fi
}

cmd_commit() {
  local repo="${1:?commit requires a repo path}"
  local msg="${2:?commit requires a message}"
  repo="$(resolve_path "$repo")"
  local name
  name="$(basename "$repo")"

  if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
    action_output "commit" "$name" "FAILED" "Not a git repository"
    return 1
  fi

  # SAFETY: Check for unmerged paths
  local unmerged
  unmerged="$(git -C "$repo" diff --name-only --diff-filter=U 2>/dev/null)"
  if [[ -n "$unmerged" ]]; then
    action_output "commit" "$name" "FAILED" "REFUSED: Unmerged paths detected. Resolve conflicts first."
    return 1
  fi

  # SAFETY: never sweep untracked env files (potential secrets) into a commit.
  # They must be gitignored or deliberately staged by the user first.
  local risky_untracked
  risky_untracked="$(git -C "$repo" status --porcelain 2>/dev/null | grep '^??' | cut -c4- \
    | grep -E '(^|/)\.env(\.|$)')" || risky_untracked=""
  if [[ -n "$risky_untracked" ]]; then
    action_output "commit" "$name" "FAILED" "REFUSED: Untracked env file(s) present: $(echo "$risky_untracked" | tr '\n' ' '). Add to .gitignore first."
    return 1
  fi

  # Stage all and commit
  git -C "$repo" add -A 2>/dev/null

  # Check if there's anything to commit
  if git -C "$repo" diff --cached --quiet 2>/dev/null; then
    action_output "commit" "$name" "FAILED" "Nothing to commit (working tree clean after staging)"
    return 1
  fi

  local output
  if output="$(git -C "$repo" commit -m "$msg" 2>&1)"; then
    action_output "commit" "$name" "OK" "$output"
  else
    action_output "commit" "$name" "FAILED" "$output"
  fi
}

cmd_setup_tracking() {
  local repo="${1:?setup-tracking requires a repo path}"
  local branch_name="${2:?setup-tracking requires a branch name}"
  repo="$(resolve_path "$repo")"
  local name
  name="$(basename "$repo")"

  if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
    action_output "setup-tracking" "$name" "FAILED" "Not a git repository"
    return 1
  fi

  local output
  if output="$(git -C "$repo" branch --set-upstream-to="origin/${branch_name}" "$branch_name" 2>&1)"; then
    action_output "setup-tracking" "$name" "OK" "$output"
  else
    action_output "setup-tracking" "$name" "FAILED" "$output"
  fi
}

cmd_clean_merged() {
  local repo="${1:?clean-merged requires a repo path}"
  repo="$(resolve_path "$repo")"
  local name
  name="$(basename "$repo")"

  if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
    action_output "clean-merged" "$name" "FAILED" "Not a git repository"
    return 1
  fi

  # Determine default branch (main or master)
  local default_branch="main"
  if ! git -C "$repo" show-ref --verify --quiet "refs/heads/main" 2>/dev/null; then
    if git -C "$repo" show-ref --verify --quiet "refs/heads/master" 2>/dev/null; then
      default_branch="master"
    fi
  fi

  # Get merged branches (exclude current branch and default branch)
  local merged_branches
  merged_branches="$(git -C "$repo" branch --merged "$default_branch" 2>/dev/null \
    | grep -v "^\*" \
    | grep -v "^[[:space:]]*${default_branch}$" \
    | sed 's/^[[:space:]]*//')"

  if [[ -z "$merged_branches" ]]; then
    action_output "clean-merged" "$name" "OK" "No merged branches to clean"
    return 0
  fi

  local deleted=()
  local failed=()
  while IFS= read -r b; do
    [[ -z "$b" ]] && continue
    if git -C "$repo" branch -d "$b" >/dev/null 2>&1; then
      deleted+=("$b")
    else
      failed+=("$b")
    fi
  done <<< "$merged_branches"

  local msg="Deleted ${#deleted[@]} branch(es)"
  if [[ ${#deleted[@]} -gt 0 ]]; then
    msg="${msg}: ${deleted[*]}"
  fi
  if [[ ${#failed[@]} -gt 0 ]]; then
    msg="${msg}. Failed to delete: ${failed[*]}"
    action_output "clean-merged" "$name" "FAILED" "$msg"
  else
    action_output "clean-merged" "$name" "OK" "$msg"
  fi
}

##############################################################################
# Main dispatch
##############################################################################

usage() {
  cat <<'USAGE'
git-sync.sh — Multi-machine git repo synchronization tool

Commands:
  audit [dir] [--no-fetch]      Scan all git repos in directory (--no-fetch: skip per-repo fetch)
  fetch-all [dir]               Fetch all repos in directory
  pull <repo>                   Pull (ff-only) a specific repo
  push <repo>                   Push a specific repo (no force)
  commit <repo> <message>       Stage all & commit in a repo
  setup-tracking <repo> <branch> Set upstream tracking
  clean-merged <repo>           Delete local branches merged into main
USAGE
}

main() {
  local cmd="${1:-}"
  shift 2>/dev/null || true

  case "$cmd" in
    audit)        cmd_audit "$@" ;;
    fetch-all)    cmd_fetch_all "$@" ;;
    pull)         cmd_pull "$@" ;;
    push)         cmd_push "$@" ;;
    commit)       cmd_commit "$@" ;;
    setup-tracking) cmd_setup_tracking "$@" ;;
    clean-merged) cmd_clean_merged "$@" ;;
    --help|-h|help|"")
      usage
      ;;
    *)
      die "Unknown command: ${cmd}. Run with --help for usage."
      ;;
  esac
}

main "$@"
