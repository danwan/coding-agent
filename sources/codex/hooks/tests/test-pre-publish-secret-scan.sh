#!/usr/bin/env bash
# Regression test for pre-publish-secret-scan.sh.
# Run: bash ~/.codex/hooks/test-pre-publish-secret-scan.sh

HOOK="$HOME/.codex/hooks/pre-publish-secret-scan.sh"
PASS=0; FAIL=0

assert_approve() {
  local name="$1" cmd="$2"
  local payload; payload=$(jq -n --arg c "$cmd" '{"tool_input":{"command":$c}}')
  local out; out=$(echo "$payload" | bash "$HOOK" 2>/dev/null)
  local exit_code=$?
  if [[ $exit_code -eq 0 && -z "$out" ]]; then
    echo "  PASS  $name"
    ((PASS++))
  else
    echo "  FAIL  $name (expected silent approve, got exit=$exit_code, stdout=$out)"
    ((FAIL++))
  fi
}

assert_block() {
  local name="$1" cmd="$2" pattern="$3"
  local payload; payload=$(jq -n --arg c "$cmd" '{"tool_input":{"command":$c}}')
  local err; err=$(echo "$payload" | bash "$HOOK" 2>&1 >/dev/null)
  local exit_code=$?
  if [[ $exit_code -ne 0 ]] && echo "$err" | grep -qF "$pattern"; then
    echo "  PASS  $name"
    ((PASS++))
  else
    echo "  FAIL  $name (expected block with '$pattern', got exit=$exit_code, stderr=$err)"
    ((FAIL++))
  fi
}

echo "=== pre-publish-secret-scan tests ==="

# --- FP regression: long hyphenated file paths in git add chains ---
assert_approve "git add long e2e path && commit" \
  "git add tests/e2e/full-suite/admin-auth-inactivity.spec.ts && git commit -m 'fix: add inactivity tests'"

assert_approve "git add multiple long paths && commit" \
  "git add lib/admin-auth.ts tests/e2e/full-suite/admin-auth-debug-state.spec.ts tests/e2e/full-suite/admin-auth-inactivity.spec.ts && git commit -m 'chore: followup'"

assert_approve "git rm and git mv paths" \
  "git rm tests/e2e/full-suite/some-long-named-test-file-that-is-old.spec.ts && git commit -m 'remove'"

assert_approve "git restore staged long path" \
  "git restore --staged tests/e2e/full-suite/admin-auth-inactivity.spec.ts"

# --- Negative: real secrets in the same chained shape MUST still block ---
FAKE_ANTHROPIC_KEY="sk-ant-api03-$(printf 'A%.0s' {1..40})"
assert_block "Anthropic key in commit message (chained)" \
  "git add foo.ts && git commit -m 'key=$FAKE_ANTHROPIC_KEY'" \
  "OpenAI/Anthropic API key"

assert_block "ENV-style secret in commit message" \
  "git add foo.ts && git commit -m 'APP_PROXY_SECRET=supersecretvalue123456'" \
  "ENV-style sensitive assignment"

# --- Negative: branch names with secret-shaped strings must still block ---
LONG_B64="$(printf 'aB1%.0s' {1..15})"  # 45 chars
assert_block "secret-shaped new branch name" \
  "git checkout -b feat/${LONG_B64}" \
  "Base64-like string"

assert_block "secret-shaped switch -c branch name" \
  "git switch -c deploy/${LONG_B64}" \
  "Base64-like string"

# --- Positive: plain short paths still work ---
assert_approve "git add simple short path && commit" \
  "git add src/index.ts && git commit -m 'refactor'"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
