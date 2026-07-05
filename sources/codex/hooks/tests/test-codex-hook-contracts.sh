#!/usr/bin/env bash
# Regression tests for Codex hook stdout/stderr contracts.

set -u

HOOK_DIR="$HOME/.codex/hooks"
PASS=0
FAIL=0

pass() {
  printf '  PASS  %s\n' "$1"
  PASS=$((PASS + 1))
}

fail() {
  printf '  FAIL  %s\n       %s\n' "$1" "$2"
  FAIL=$((FAIL + 1))
}

payload_for_command() {
  jq -n --arg c "$1" '{
    session_id: "test-session",
    turn_id: "test-turn",
    transcript_path: null,
    cwd: env.PWD,
    hook_event_name: "PreToolUse",
    model: "test-model",
    permission_mode: "dontAsk",
    tool_name: "Bash",
    tool_use_id: "test-tool",
    tool_input: { command: $c }
  }'
}

assert_silent_approve() {
  local name="$1" hook="$2" cmd="$3"
  local stdout stderr exit_code payload
  payload=$(payload_for_command "$cmd")
  stdout=$(mktemp)
  stderr=$(mktemp)
  printf '%s' "$payload" | bash "$hook" >"$stdout" 2>"$stderr"
  exit_code=$?
  if [[ $exit_code -eq 0 && ! -s "$stdout" ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 0 with empty stdout; got exit=$exit_code stdout=$(cat "$stdout") stderr=$(cat "$stderr")"
  fi
  rm -f "$stdout" "$stderr"
}

assert_block_stderr() {
  local name="$1" hook="$2" cmd="$3" expected="$4"
  local stdout stderr exit_code payload
  payload=$(payload_for_command "$cmd")
  stdout=$(mktemp)
  stderr=$(mktemp)
  printf '%s' "$payload" | bash "$hook" >"$stdout" 2>"$stderr"
  exit_code=$?
  if [[ $exit_code -eq 2 && ! -s "$stdout" ]] && grep -qF "$expected" "$stderr"; then
    pass "$name"
  else
    fail "$name" "expected exit 2 with stderr containing '$expected'; got exit=$exit_code stdout=$(cat "$stdout") stderr=$(cat "$stderr")"
  fi
  rm -f "$stdout" "$stderr"
}

assert_json_message() {
  local name="$1" hook="$2" cmd="$3" expected="$4"
  local stdout stderr exit_code payload
  payload=$(payload_for_command "$cmd")
  stdout=$(mktemp)
  stderr=$(mktemp)
  printf '%s' "$payload" | bash "$hook" >"$stdout" 2>"$stderr"
  exit_code=$?
  if [[ $exit_code -eq 0 ]] && jq -e --arg expected "$expected" '
    (has("result") | not) and (.systemMessage | contains($expected))
  ' "$stdout" >/dev/null; then
    pass "$name"
  else
    fail "$name" "expected Codex JSON systemMessage containing '$expected'; got exit=$exit_code stdout=$(cat "$stdout") stderr=$(cat "$stderr")"
  fi
  rm -f "$stdout" "$stderr"
}

assert_session_json() {
  local name="$1" hook="$2"
  local stdout stderr exit_code payload
  payload=$(jq -n '{
    session_id: "test-session",
    transcript_path: null,
    cwd: env.PWD,
    hook_event_name: "SessionStart",
    model: "test-model",
    permission_mode: "dontAsk",
    source: "startup"
  }')
  stdout=$(mktemp)
  stderr=$(mktemp)
  printf '%s' "$payload" | bash "$hook" >"$stdout" 2>"$stderr"
  exit_code=$?
  if [[ $exit_code -eq 0 ]] && jq -e '
    (has("result") | not) and (has("systemMessage") or has("hookSpecificOutput"))
  ' "$stdout" >/dev/null; then
    pass "$name"
  else
    fail "$name" "expected Codex SessionStart JSON without result; got exit=$exit_code stdout=$(cat "$stdout") stderr=$(cat "$stderr")"
  fi
  rm -f "$stdout" "$stderr"
}

echo "=== Codex hook contract tests ==="

assert_silent_approve "backend guard ignores non-push commands" \
  "$HOOK_DIR/check-backend-deploy.sh" "printf test"

assert_silent_approve "backend guard allows push without backend diff" \
  "$HOOK_DIR/check-backend-deploy.sh" "git push"

tmp_repo=$(mktemp -d)
(
  cd "$tmp_repo" || exit 1
  git init -q -b main
  git config user.email test@example.com
  git config user.name "Test User"
  mkdir convex
  printf 'export const ok = true;\n' > convex/example.ts
  git add convex/example.ts
  git commit -q -m init
  git checkout -q -b feature/hooks
  printf 'export const ok = false;\n' > convex/example.ts
  assert_json_message "backend guard warns with valid Codex JSON" \
    "$HOOK_DIR/check-backend-deploy.sh" "git push" "CONVEX"
)
rm -rf "$tmp_repo"

assert_silent_approve "secret scan silently approves normal commands" \
  "$HOOK_DIR/pre-publish-secret-scan.sh" "printf test"

assert_block_stderr "secret scan blocks denied commands with stderr reason" \
  "$HOOK_DIR/pre-publish-secret-scan.sh" "rm -rf .next" "Blocked by Codex permission parity"

assert_block_stderr "secret scan blocks publish secrets with stderr reason" \
  "$HOOK_DIR/pre-publish-secret-scan.sh" \
  "git commit -m 'APP_PROXY_SECRET=supersecretvalue123456'" \
  "BLOCKED by pre-publish-secret-scan"

assert_session_json "session-start emits Codex-compatible JSON" \
  "$HOOK_DIR/session-start.sh"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
