#!/bin/bash
# PostToolUse hook: Format TypeScript files after Write

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

# Only process TypeScript files
[[ "$FILE_PATH" != *.ts && "$FILE_PATH" != *.tsx ]] && exit 0

# Walk up to find package.json with prettier dependency
find_prettier_project() {
  local dir="$1"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/package.json" ]]; then
      if jq -e '(.dependencies.prettier // .devDependencies.prettier) // empty' "$dir/package.json" >/dev/null 2>&1; then
        echo "$dir"
        return 0
      fi
      return 1
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

FILE_DIR=$(dirname "$FILE_PATH")
PROJECT_ROOT=$(find_prettier_project "$FILE_DIR") || exit 0

# Find local prettier binary — walk up from file dir to find node_modules/.bin/prettier
find_prettier_bin() {
  local dir="$1"
  while [[ "$dir" != "/" ]]; do
    if [[ -x "$dir/node_modules/.bin/prettier" ]]; then
      echo "$dir/node_modules/.bin/prettier"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

PRETTIER=$(find_prettier_bin "$FILE_DIR") || {
  # No local binary — try global prettier, otherwise skip
  command -v prettier >/dev/null 2>&1 && PRETTIER="prettier" || exit 0
}

# Only format if file actually needs changes
$PRETTIER --check "$FILE_PATH" >/dev/null 2>&1 || $PRETTIER --write "$FILE_PATH" 2>/dev/null

exit 0
