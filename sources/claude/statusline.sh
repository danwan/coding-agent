#!/usr/bin/env bash
# ~/.claude/statusline.sh — codex-style statusline
# Format: model · path · branch · Context X% left · 5h X% · weekly X%

set -euo pipefail

INPUT=$(cat)

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // .workspace.current_dir // ""')
MODEL=$(printf '%s' "$INPUT" | jq -r '.model.display_name // .model.id // ""')
CTX_TOKENS=$(printf '%s' "$INPUT" | jq -r '.context_window.total_input_tokens // empty')
FIVE_HOUR_USED=$(printf '%s' "$INPUT" | jq -r '.rate_limits.five_hour.used_percentage // empty')
SEVEN_DAY_USED=$(printf '%s' "$INPUT" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# ── ANSI colors (256-color, dark-bg friendly) ────────────────────────────────
ESC=$'\e'
RESET="${ESC}[0m"
ORANGE="${ESC}[38;5;215m"   # model + Context
KHAKI="${ESC}[38;5;186m"    # path
CYAN="${ESC}[38;5;117m"     # branch
PINK="${ESC}[38;5;211m"     # rate limits
DIM="${ESC}[38;5;240m"      # separator dot

SEP=" ${DIM}·${RESET} "

shorten_path() {
  local p="$1" home="${HOME:-/Users/$(whoami)}"
  printf '%s' "${p/#$home/\~}"
}

PARTS=()

# 1. Model name (e.g. "Opus 4.7")
if [[ -n "$MODEL" ]]; then
  PARTS+=("${ORANGE}${MODEL}${RESET}")
fi

# 2. Path
if [[ -n "$CWD" ]]; then
  PARTS+=("${KHAKI}$(shorten_path "$CWD")${RESET}")
fi

# 3. Branch (or no-git) + open PR count from gh
if [[ -n "$CWD" ]] && command -v git &>/dev/null; then
  GIT_ROOT=$(GIT_OPTIONAL_LOCKS=0 git -C "$CWD" rev-parse --show-toplevel 2>/dev/null || true)
  if [[ -n "$GIT_ROOT" ]]; then
    BRANCH=$(GIT_OPTIONAL_LOCKS=0 git -C "$GIT_ROOT" symbolic-ref --short HEAD 2>/dev/null \
      || GIT_OPTIONAL_LOCKS=0 git -C "$GIT_ROOT" rev-parse --short HEAD 2>/dev/null \
      || true)
    if [[ -n "$BRANCH" ]]; then
      BRANCH_SEG="${CYAN}${BRANCH}${RESET}"

      # Open PRs (cached 5min) — appended as " +N" if any
      REMOTE_URL=$(GIT_OPTIONAL_LOCKS=0 git -C "$GIT_ROOT" remote get-url origin 2>/dev/null || true)
      if [[ "$REMOTE_URL" == *"github.com"* ]] && command -v gh &>/dev/null; then
        CACHE_DIR="${TMPDIR:-/tmp}/claude-statusline"
        mkdir -p "$CACHE_DIR" 2>/dev/null || true
        CACHE_KEY=$(printf '%s' "$GIT_ROOT" | tr '/' '_' | tr -cd '[:alnum:]_-')
        CACHE_FILE="$CACHE_DIR/prs_${CACHE_KEY}.cache"
        NOW=$(date +%s)
        PR_COUNT=""
        if [[ -f "$CACHE_FILE" ]]; then
          CACHE_MTIME=$(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
          if (( NOW - CACHE_MTIME < 300 )); then
            PR_COUNT=$(cat "$CACHE_FILE" 2>/dev/null || echo "")
          fi
        fi
        if [[ -z "$PR_COUNT" ]]; then
          # macOS has no `timeout`; pick gtimeout if installed, else run unguarded
          TIMEOUT_CMD=""
          if command -v gtimeout &>/dev/null; then TIMEOUT_CMD="gtimeout 4"
          elif command -v timeout &>/dev/null; then TIMEOUT_CMD="timeout 4"
          fi
          GH_OUT=$(cd "$GIT_ROOT" && $TIMEOUT_CMD gh pr list --state open --json number 2>/dev/null || echo "")
          if [[ -n "$GH_OUT" ]]; then
            PR_COUNT=$(printf '%s' "$GH_OUT" | jq 'length' 2>/dev/null || echo "")
            [[ -n "$PR_COUNT" ]] && printf '%s' "$PR_COUNT" > "$CACHE_FILE"
          fi
        fi
        if [[ -n "$PR_COUNT" && "$PR_COUNT" -gt 0 ]]; then
          BRANCH_SEG="${BRANCH_SEG} ${CYAN}+${PR_COUNT}${RESET}"
        fi
      fi

      PARTS+=("$BRANCH_SEG")
    fi
  else
    PARTS+=("${DIM}no-git${RESET}")
  fi
fi

# 4. Context window (used tokens)
if [[ -n "$CTX_TOKENS" ]]; then
  if (( CTX_TOKENS >= 1000000 )); then
    CTX_FMT=$(awk -v n="$CTX_TOKENS" 'BEGIN { printf "%.1fM", n/1000000 }')
  elif (( CTX_TOKENS >= 1000 )); then
    CTX_FMT=$(awk -v n="$CTX_TOKENS" 'BEGIN { printf "%.1fk", n/1000 }')
  else
    CTX_FMT="$CTX_TOKENS"
  fi
  PARTS+=("${ORANGE}C:${CTX_FMT}${RESET}")
fi

# 5. 5-hour limit (% left)
if [[ -n "$FIVE_HOUR_USED" ]]; then
  FH_INT=$(printf '%.0f' "$FIVE_HOUR_USED" 2>/dev/null || echo "")
  if [[ -n "$FH_INT" ]]; then
    FH_LEFT=$((100 - FH_INT))
    PARTS+=("${PINK}5h ${FH_LEFT}%${RESET}")
  fi
fi

# 6. Weekly limit (% left)
if [[ -n "$SEVEN_DAY_USED" ]]; then
  SD_INT=$(printf '%.0f' "$SEVEN_DAY_USED" 2>/dev/null || echo "")
  if [[ -n "$SD_INT" ]]; then
    SD_LEFT=$((100 - SD_INT))
    PARTS+=("${PINK}weekly ${SD_LEFT}%${RESET}")
  fi
fi

# ── Assemble with " · " separator ────────────────────────────────────────────
if [[ ${#PARTS[@]} -gt 0 ]]; then
  out=""
  for p in "${PARTS[@]}"; do
    [[ -n "$out" ]] && out+="$SEP"
    out+="$p"
  done
  printf '%s\n' "$out"
fi
