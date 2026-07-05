#!/bin/bash
# PostToolUse hook: Format TypeScript files after Write

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Exit silently if no file path

# CODEX_FORMAT_FALLBACK: Codex does not expose Codex Write/Edit hooks 1:1.
# When invoked without file_path, format changed TypeScript files in the current git worktree.
if [[ -z "$FILE_PATH" ]]; then
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
  PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
  [ -f "$PROJECT_ROOT/package.json" ] || exit 0
  PRETTIER="$PROJECT_ROOT/node_modules/.bin/prettier"
  [ -x "$PRETTIER" ] || command -v prettier >/dev/null 2>&1 || exit 0
  FORMATTER="$PRETTIER"
  [ -x "$FORMATTER" ] || FORMATTER="prettier"
  files=$( { git diff --name-only --diff-filter=ACMRTUXB; git ls-files --others --exclude-standard; } | grep -E '\.(ts|tsx)$' || true )
  [ -z "$files" ] && exit 0
  printf '%s\n' "$files" | xargs "$FORMATTER" --write >/dev/null 2>&1 || true
  exit 0
fi

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
