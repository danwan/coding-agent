#!/bin/bash
# PostToolUse hook: Format Python files after Write

# Dual-mode: OpenCode formatter passes the file path as $1; Claude Code passes
# stdin JSON ({tool_input:{file_path}}). Accept $1 first, fall back to stdin.
if [[ -n "${1:-}" ]]; then
  FILE_PATH="$1"
else
  INPUT=$(cat)
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
fi

# Exit silently if no file path
[[ -z "$FILE_PATH" ]] && exit 0

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
