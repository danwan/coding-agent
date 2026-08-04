#!/usr/bin/env bash
# Read-only Inventar für das Test-/CI-Audit (Phase 1).
# Aufruf im Repo-Root:  ./inventory.sh [owner/repo]
# Ohne Argument wird owner/repo aus dem origin-Remote abgeleitet.
# Gibt Abschnitte als "== TITEL ==" aus; API-Fehler erscheinen als
# "NICHT PRÜFBAR: <grund>" statt den Lauf abzubrechen.
set -u

repo="${1:-}"
if [ -z "$repo" ]; then
  repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)
fi

section() { printf '\n== %s ==\n' "$1"; }
unverifiable() { printf 'NICHT PRÜFBAR: %s\n' "$1"; }

section "REPO"
echo "path: $(pwd)"
echo "remote: ${repo:-<kein GitHub-Remote erkannt>}"
git rev-parse --abbrev-ref HEAD 2>/dev/null | sed 's/^/branch: /'

section "STACK-SIGNATUREN"
[ -f package.json ] && grep -q '"next"' package.json && echo "next.js"
[ -d convex ] && ls convex/*.ts convex/**/*.ts 2>/dev/null | grep -qv _generated && echo "convex"
{ [ -f vercel.json ] || ls next.config.* >/dev/null 2>&1; } && echo "vercel"
[ -f pyproject.toml ] && echo "python (pyproject)"
grep -rqs 'import modal\|from modal' --include='*.py' . 2>/dev/null && echo "modal"
{ [ -d app/api ] || [ -d pages/api ] || [ -d convex ] || ls middleware.* >/dev/null 2>&1; } && echo "server-endpoints"
grep -rqs 'better-sqlite3\|drizzle' package.json 2>/dev/null && echo "sqlite/drizzle"

section "TEST-KOMMANDOS (Manifeste)"
[ -f package.json ] && jq -r '.scripts | to_entries[] | select(.key | test("test|lint|typecheck|check|e2e")) | "\(.key): \(.value)"' package.json 2>/dev/null
[ -f pyproject.toml ] && grep -A4 'tool.pytest' pyproject.toml 2>/dev/null
[ -f pytest.ini ] && cat pytest.ini
[ -f Makefile ] && grep -E '^(test|verify|e2e)[a-zA-Z0-9_-]*:' Makefile

section "RUNNER-CONFIGS"
ls vitest.config.* playwright.config.* jest.config.* 2>/dev/null
[ -f pyproject.toml ] && grep -l 'tool.pytest' pyproject.toml 2>/dev/null

section "TESTDATEI-VERTEILUNG"
unit=$(find . -path ./node_modules -prune -o -path ./.venv -prune -o -path ./.next -prune -o -path ./.git -prune -o \
  -type f \( -name '*.test.*' -o -name '*_test.py' -o -name 'test_*.py' -o -name '*.spec.*' \) -print 2>/dev/null | grep -cv '/e2e/')
e2e=$(find . -path ./node_modules -prune -o -path ./.git -prune -o -type f \( -name '*.spec.ts' -o -name '*.spec.js' \) -path '*e2e*' -print 2>/dev/null | wc -l | tr -d ' ')
echo "unit/integration-artige Dateien: $unit"
echo "e2e-Spec-Dateien: $e2e"

section "CI-WORKFLOWS"
if [ -d .github/workflows ]; then
  for f in .github/workflows/*.yml .github/workflows/*.yaml; do
    [ -f "$f" ] || continue
    echo "--- $f"
    grep -nE '^(name:|on:|  (pull_request|push|schedule|workflow_dispatch|deployment_status)|    paths-ignore|    paths:|concurrency:|  cancel-in-progress|^jobs:|^  [a-zA-Z0-9_-]+:$|    name:|    timeout-minutes|.*continue-on-error|.*\|\| true|    - cron:)' "$f"
  done
else
  echo "keine .github/workflows/ — keine CI"
fi

if [ -n "$repo" ] && gh auth status >/dev/null 2>&1; then
  section "RULESETS (API)"
  gh api "repos/$repo/rulesets" --jq '.[] | "\(.id) \(.name) \(.enforcement)"' 2>/dev/null || unverifiable "rulesets-API fehlgeschlagen"
  gh api "repos/$repo/rules/branches/main" --jq '.[].type' 2>/dev/null | sort | uniq -c

  section "KLASSISCHE BRANCH-PROTECTION (API)"
  gh api "repos/$repo/branches/main/protection" --jq '.required_status_checks.contexts' >/dev/null 2>&1 \
    && gh api "repos/$repo/branches/main/protection" --jq '.required_status_checks.contexts' 2>/dev/null \
    || echo "keine (404 ist hier der Normalfall)"

  section "LETZTE LÄUFE AUF MAIN (API)"
  gh run list -R "$repo" -b main -L 10 --json name,event,conclusion,createdAt \
    --jq '.[] | "\(.createdAt) \(.name) [\(.event)] \(.conclusion)"' 2>/dev/null || unverifiable "run-Liste fehlgeschlagen"

  section "CHECK-RUN-NAMEN AM LETZTEN MAIN-COMMIT (API)"
  sha=$(gh api "repos/$repo/commits/main" --jq .sha 2>/dev/null)
  [ -n "${sha:-}" ] && gh api "repos/$repo/commits/$sha/check-runs" --jq '.check_runs[].name' 2>/dev/null | sort -u

  section "FIX-COMMIT-STICHPROBE (P3)"
  git log --oneline -30 2>/dev/null | grep -iE 'fix|bug' | head -10
else
  section "API-PRÜFUNGEN"
  unverifiable "gh nicht authentifiziert oder kein GitHub-Remote — Rulesets, Protection, Läufe und Check-Namen im Bericht als 'nicht prüfbar' ausweisen"
fi
