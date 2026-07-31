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

# No file path at all. Two very different cases:
#  - nothing on stdin and no argv  -> the hook fired on an event that carries no
#    file (e.g. wired to Stop instead of PostToolUse), or a harness whose payload
#    uses different field names. Say so: a formatter that silently does nothing
#    is indistinguishable from one that ran and found nothing to change.
#  - genuinely empty input          -> nothing to do.
if [[ -z "$FILE_PATH" ]]; then
  if [[ -n "${INPUT:-}" ]]; then
    printf '%s\n' "format-typescript.sh: kein .tool_input.file_path im Hook-Payload — falsches Event oder fremdes Schema; es wurde nichts formatiert" >&2
  fi
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
