#!/usr/bin/env bash
# Wait for CI checks on a PR. Usage: wait-ci.sh <pr-number> [repo] [timeout-min]
# Exit: 0 = all green, 1 = failure, 2 = timeout, 3 = no checks.
set -euo pipefail

PR="${1:?usage: wait-ci.sh <pr-number> [repo] [timeout-min]}"
REPO="${2:-}"
TIMEOUT_MIN="${3:-20}"
[[ -n "$REPO" ]] && REPO_ARG=(-R "$REPO") || REPO_ARG=()

DEADLINE=$(( $(date +%s) + TIMEOUT_MIN * 60 ))

while :; do
  CHECKS=""
  # `gh pr checks` returns a non-zero exit status while checks are pending or
  # failed, even though its JSON output is valid and must still be evaluated.
  if ! CHECKS="$(gh pr checks "$PR" "${REPO_ARG[@]}" --json name,state 2>/dev/null)"; then
    :
  fi
  if ! jq -e 'type == "array"' >/dev/null 2>&1 <<<"$CHECKS"; then
    CHECKS='[]'
  fi
  TOTAL="$(jq length <<<"$CHECKS")"
  if [[ "$TOTAL" -eq 0 ]]; then
    if [[ "$(date +%s)" -ge "$DEADLINE" ]]; then
      printf '%s\n' "NO_CHECKS"
      exit 3
    fi
    sleep 20
    continue
  fi

  FAILED="$(jq '[.[] | select(.state=="FAILURE" or .state=="ERROR" or .state=="CANCELLED")] | length' <<<"$CHECKS")"
  PENDING="$(jq '[.[] | select(.state!="SUCCESS" and .state!="FAILURE" and .state!="ERROR" and .state!="CANCELLED" and .state!="SKIPPED" and .state!="NEUTRAL")] | length' <<<"$CHECKS")"

  if [[ "$FAILED" -gt 0 && "$PENDING" -eq 0 ]]; then
    printf 'RED: %s/%s failed\n' "$FAILED" "$TOTAL"
    jq -r '.[] | select(.state=="FAILURE" or .state=="ERROR" or .state=="CANCELLED") | "  - \(.name): \(.state)"' <<<"$CHECKS"
    exit 1
  fi
  if [[ "$PENDING" -eq 0 ]]; then
    printf 'GREEN: %s checks passed\n' "$TOTAL"
    exit 0
  fi
  if [[ "$(date +%s)" -ge "$DEADLINE" ]]; then
    printf 'TIMEOUT: %s/%s still pending after %smin\n' "$PENDING" "$TOTAL" "$TIMEOUT_MIN"
    exit 2
  fi
  sleep 30
done
