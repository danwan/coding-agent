#!/bin/bash
# PostToolUse hook: Format Python files after Write

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Exit silently if no file path

# CODEX_FORMAT_FALLBACK: Codex does not expose Codex Write/Edit hooks 1:1.
# When invoked without file_path, format changed Python files in the current git worktree.
if [[ -z "$FILE_PATH" ]]; then
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
  command -v ruff >/dev/null 2>&1 || exit 0
  files=$( { git diff --name-only --diff-filter=ACMRTUXB; git ls-files --others --exclude-standard; } | grep -E '\.py$' || true )
  [ -z "$files" ] && exit 0
  while IFS= read -r file; do
    [ -f "$file" ] || continue
    if ! ruff format --check "$file" >/dev/null 2>&1; then
      ruff check "$file" --fix 2>/dev/null || true
      ruff format "$file" 2>/dev/null || true
    fi
  done <<< "$files"
  exit 0
fi

# Only process Python files
[[ "$FILE_PATH" != *.py ]] && exit 0

# Walk up to find pyproject.toml or ruff.toml
find_ruff_config() {
  local dir="$1"
  while [[ "$dir" != "/" ]]; do
    [[ -f "$dir/ruff.toml" || -f "$dir/pyproject.toml" ]] && return 0
    dir=$(dirname "$dir")
  done
  return 1
}

FILE_DIR=$(dirname "$FILE_PATH")
find_ruff_config "$FILE_DIR" || exit 0

# Check for ruff availability
command -v ruff >/dev/null 2>&1 || exit 0

# Only format if file actually needs changes
if ! ruff format --check "$FILE_PATH" >/dev/null 2>&1; then
  ruff check "$FILE_PATH" --fix 2>/dev/null
  ruff format "$FILE_PATH" 2>/dev/null
fi

exit 0
