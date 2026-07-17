# Deploy-Safety — Post-mortem, Canonical Template & Retrofit

> **Consult-on-demand reference.** NOT auto-loaded into CLAUDE.md.
> Use this when:
> - You hit a deploy issue and need the incident background
> - You're creating a new deploy script (use the canonical template)
> - You're retrofitting an old script to the v2 hardening
>
> The enforceable rule (10 gates + lint rule) lives in `~/.claude/rules/deploy-safety.md`.

---

## Background — The 2026-04-19 Incident

Codified from the lanalyzer-overwrite incident (2026-04-19, svb-manager deploy session).
Root cause: `~/.zshrc` exported a generic `CONVEX_PROD_DEPLOY_KEY` that was lanalyzer's key;
svb-manager's deploy script fell back to the shell env and silently deployed to the wrong Convex instance.

---

## Globally Exported Secrets in ~/.zshrc — Past Risk — Currently Absent (verified 2026-04-30, this machine)

> **STATUS (Live-Check 2026-04-30, this machine):** Die drei Exports sind aktuell nicht mehr aktiv. Verifiziert in `~/.zshrc`, `~/.zprofile`, `~/.profile`, `/etc/profile`, `/etc/zprofile`, `/etc/zshrc`, `/etc/bashrc`, `~/.claude/settings.json`, `~/.claude.json`, im aktuellen Process-Env und via `launchctl getenv` (macOS-spezifische Env-Quelle). `~/.bashrc`, `~/.bash_profile`, `~/.zshenv`, `~/.envrc` existieren auf dieser Maschine nicht. Eine Re-Introduktion durch dotfile-Sync, neuen Installer, 1Password-Auto-Load oder eine andere Maschine ist nicht ausgeschlossen — die Tabelle bleibt als Inzidenz-Referenz und als Wachhinweis.

As of 2026-04-19, the following vars were exported globally in `~/.zshrc`:

| Variable | Value | Originally for | Risk |
|----------|-------|----------------|------|
| `CONVEX_PROD_DEPLOY_KEY` | `<REDACTED:convex-deployment>` | lanalyzer | **HIGH** — causes wrong-instance deploy in any project whose script does `${CONVEX_PROD_DEPLOY_KEY}` |
| `CONVEX_DEV_DEPLOY_KEY` | `<REDACTED:convex-deployment>` | lanalyzer | MEDIUM — same pattern for dev |
| `VERCEL_TOKEN` | `<REDACTED:vercel-token — rotate>` | cross-project | LOW-MEDIUM — any project's Vercel CLI call works without explicit configuration |

> **Redaction note:** the concrete values that used to sit in this table have been
> removed — this is a public repo. The `VERCEL_TOKEN` value was a full-length token
> and must be treated as compromised → **rotate it in Vercel**. The Convex entries
> were deployment-name prefixes (the secret is the part after `|`, never stored here).

**Recommended action (manual — do not automate):** Remove these from `~/.zshrc`. See the manual steps section below.

---

## Reference: Canonical Deploy Script Template

Template incorporating learnings from l-automation hardening (2026-04-19+):
- CRLF-safe key extraction (`tr -d '\r'`)
- Whitespace-trimming on key (parameter expansion)
- Strict format regex (not just prefix — also requires non-trivial token)
- `cd "$SCRIPT_DIR"` so all `git` calls target the project repo regardless of caller CWD
- Detached-HEAD explicit check
- Origin remote existence check before `git fetch`
- `ls-files --others` captured to var (set-e doesn't propagate from `[[ $(...) ]]`)
- Post-deploy verification captures + validates non-empty output (no `2>/dev/null` hiding auth failures)

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"  # anchor all git + relative paths to the repo root
ENV_FILE="${SCRIPT_DIR}/.env"

# Gate 4: hardcoded target — edit this when you create the project, never change after
EXPECTED_DEPLOYMENT="<paste-convex-prod-id-here>"

# --- Local safety gates (CLAUDE.md Golden Rule "Branch = Environment") — not part of the 10-gate contract ---

# Branch guard — catches detached HEAD explicitly instead of reporting "currently on ''"
BRANCH=$(git branch --show-current)
if [[ -z "$BRANCH" ]]; then
  echo "ERROR: Detached HEAD — checkout 'main' first." >&2
  exit 1
fi
if [ "$BRANCH" != "main" ]; then
  echo "ERROR: Production deploy must be from 'main' (currently on '$BRANCH')" >&2
  exit 1
fi

# Clean-tree check (diff + staged + untracked). Capture ls-files to var — `$(…)`
# inside `[[ … ]]` swallows git failures silently under set -e.
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: Working tree has uncommitted changes. Commit or stash first." >&2
  exit 1
fi
UNTRACKED=$(git ls-files --others --exclude-standard)
if [[ -n "$UNTRACKED" ]]; then
  echo "ERROR: Untracked files present. Commit, stash, or clean first." >&2
  exit 1
fi

# Origin-sync check
if ! git remote get-url origin >/dev/null 2>&1; then
  echo "ERROR: 'origin' remote not configured." >&2
  exit 1
fi
git fetch origin main
if [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]]; then
  echo "ERROR: HEAD is not in sync with origin/main. Pull/push first." >&2
  exit 1
fi

# --- 10-gate contract ---

# Reject duplicated `.env` entries loudly — silent first-match picking would
# let an outdated / wrong duplicate win.
KEY_LINE_COUNT=$(grep -c '^CONVEX_DEPLOYMENT_PROD=' "$ENV_FILE" || true)
if [[ "$KEY_LINE_COUNT" -gt 1 ]]; then
  echo "ERROR: Multiple CONVEX_DEPLOYMENT_PROD entries in $ENV_FILE — pick one and remove duplicates." >&2
  exit 1
fi

# Gate 2+3: read from .env only (no shell-env fallback).
#   - `|| true` is load-bearing: grep returns exit 1 on no-match; without this
#     `set -euo pipefail` kills the script silently before the `[[ -z "$KEY" ]]`
#     friendly error path can print the generate URL.
#   - `sed 's/^"//; s/"$//'` strips surrounding double quotes (common in .env).
#   - `tr -d '\r'` handles CRLF line endings from Windows editors.
#   - parameter expansion trims surrounding whitespace (defense-in-depth; Gate 4
#     regex would reject it anyway, but silent trim is friendlier than a cryptic
#     format error for purely accidental whitespace).
KEY=$(grep '^CONVEX_DEPLOYMENT_PROD=' "$ENV_FILE" 2>/dev/null | cut -d'=' -f2- | sed 's/^"//; s/"$//' | tr -d '\r' || true)
KEY="${KEY#"${KEY%%[![:space:]]*}"}"
KEY="${KEY%"${KEY##*[![:space:]]}"}"
if [[ -z "$KEY" ]]; then
  echo "ERROR: CONVEX_DEPLOYMENT_PROD not set in $ENV_FILE" >&2
  exit 1
fi

# Gate 4: strict format check (prefix + '|' + non-trivial token).
# A plain prefix check would pass malformed values like "prod:<id>" (no '|<token>')
# which then fail opaquely inside `npx convex deploy`.
if [[ ! "$KEY" =~ ^prod:${EXPECTED_DEPLOYMENT}\|[A-Za-z0-9+=/_-]{20,}$ ]]; then
  echo "ERROR: Key does not match required format 'prod:${EXPECTED_DEPLOYMENT}|<token>'" >&2
  echo "       Got prefix: ${KEY%%|*}" >&2
  exit 1
fi

# Gate 8: echo target before deploying
echo "Deploying to Convex Prod: ${EXPECTED_DEPLOYMENT}"

CONVEX_DEPLOY_KEY="$KEY" npx convex deploy --yes

# Gate 10: post-deploy verification.
# `set -euo pipefail` kills the script on command failure (auth, network).
# Empty output = "no env vars set" which is legit for a fresh deployment —
# print a marker instead of hard-failing, so brand-new projects still work.
# Do NOT redirect stderr: let real errors surface.
ENV_VARS=$(CONVEX_DEPLOY_KEY="$KEY" npx convex env list | cut -d'=' -f1 | sort)
echo "Env vars on ${EXPECTED_DEPLOYMENT}:"
if [[ -z "$ENV_VARS" ]]; then
  echo "  (none — verify this is expected for a fresh deployment)"
else
  echo "$ENV_VARS"
fi
```

---

## Retrofit Checklist for Existing Projects

Use this whenever you revisit a project that has deploy scripts written against an older version of this template. The 10 core gates may already be in place (most projects after the 2026-04-19 incident fix); the v2 learnings below are **silent-failure hardening** surfaced by the l-automation session on 2026-04-19.

### Fast audit (run first)

```bash
cd <project-root>
awk '
  /^[[:space:]]*#/                                 { next }
  /source \.env/                                   { print "FORBIDDEN/source-env:"FILENAME":"NR": "$0 }
  /\$\{?CONVEX_(PROD|DEV)?_DEPLOY_KEY\}?/          { print "FORBIDDEN/shell-expand:"FILENAME":"NR": "$0 }
  /^[[:space:]]*CONVEX_(PROD|DEV)_DEPLOY_KEY=/     { print "FORBIDDEN/old-name:"FILENAME":"NR": "$0 }
  /tr -d .\\r./                                     { has_crlf=1 }
  /cd "\$SCRIPT_DIR"/                               { has_cd=1 }
  /Detached HEAD|detached.HEAD/                     { has_detached=1 }
  /EXPECTED_DEPLOYMENT/                             { has_expected=1 }
  /git ls-files --others/                           { has_untracked=1 }
  /git remote get-url origin/                       { has_origin=1 }
  /\[\[ ! "\$KEY" =~/                               { has_format=1 }
  /ENV_VARS=.*convex env list/                      { has_verify=1 }
  END {
    print "v1 core (post-2026-04-19):"
    print "  EXPECTED_DEPLOYMENT constant: " (has_expected+0)
    print "  untracked-files check:        " (has_untracked+0)
    print "v2 learnings (post-2026-04-19 session):"
    print "  CRLF strip (tr -d \\r):        " (has_crlf+0)
    print "  cd \$SCRIPT_DIR:               " (has_cd+0)
    print "  detached-HEAD check:          " (has_detached+0)
    print "  origin remote check:          " (has_origin+0)
    print "  strict format regex:          " (has_format+0)
    print "  post-deploy verify capture:   " (has_verify+0)
  }
' deploy-backend*.sh
```

If any `FORBIDDEN/*` line appears → **CRITICAL**, stop and fix before next deploy.
If v1 core missing → script predates the 2026-04-19 incident fix; rewrite from the canonical template above.
If v2 learnings missing → not acute, but apply before the next script edit (cheap defense-in-depth).

### Apply v2 learnings (copy-paste diffs)

**1. `cd "$SCRIPT_DIR"`** — right after `SCRIPT_DIR=...`:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"  # ← add this
```

**2. Detached-HEAD explicit check** — replace plain branch guard:
```bash
BRANCH=$(git branch --show-current)
if [[ -z "$BRANCH" ]]; then
  echo "ERROR: Detached HEAD — checkout 'main' first." >&2
  exit 1
fi
if [ "$BRANCH" != "main" ]; then
  echo "ERROR: Production deploy must be from 'main' (currently on '$BRANCH')" >&2
  exit 1
fi
```

**3. Origin-remote existence check** — before `git fetch`:
```bash
if ! git remote get-url origin >/dev/null 2>&1; then
  echo "ERROR: 'origin' remote not configured." >&2
  exit 1
fi
git fetch origin main
```

**4. CRLF-safe + whitespace-trim key extraction + duplicate-key guard** — `head -n1` would silently pick one of two duplicated entries; counting first and failing loudly is safer:
```bash
KEY_LINE_COUNT=$(grep -c '^CONVEX_DEPLOYMENT_PROD=' "$ENV_FILE" || true)
if [[ "$KEY_LINE_COUNT" -gt 1 ]]; then
  echo "ERROR: Multiple CONVEX_DEPLOYMENT_PROD entries in $ENV_FILE" >&2
  exit 1
fi
KEY=$(grep '^CONVEX_DEPLOYMENT_PROD=' "$ENV_FILE" 2>/dev/null | cut -d'=' -f2- | sed 's/^"//; s/"$//' | tr -d '\r' || true)
KEY="${KEY#"${KEY%%[![:space:]]*}"}"
KEY="${KEY%"${KEY##*[![:space:]]}"}"
```

**5. Strict format regex** — replace plain prefix check:
```bash
if [[ ! "$KEY" =~ ^prod:${EXPECTED_DEPLOYMENT}\|[A-Za-z0-9+=/_-]{20,}$ ]]; then
  echo "ERROR: Key does not match required format 'prod:${EXPECTED_DEPLOYMENT}|<token>'" >&2
  echo "       Got prefix: ${KEY%%|*}" >&2
  exit 1
fi
```

**6. Post-deploy verification that surfaces command failures** — replace the decorative env-list line. `set -euo pipefail` handles real failures; empty output is legitimate on a fresh project, so warn instead of fail:
```bash
ENV_VARS=$(CONVEX_DEPLOY_KEY="$KEY" npx convex env list | cut -d'=' -f1 | sort)
if [[ -z "$ENV_VARS" ]]; then
  echo "  (no env vars set — verify this is expected for a fresh deployment)"
else
  echo "$ENV_VARS"
fi
```

### Sabotage tests after retrofit

Run these in the project root with a clean `.env.backup`:

```bash
cp .env /tmp/env.backup

# T1: wrong-prefix key must be rejected
python3 -c "import re; c=open('.env').read(); open('.env','w').write(re.sub(r'^CONVEX_DEPLOYMENT_PROD=.*$','CONVEX_DEPLOYMENT_PROD=\"prod:wrong|fake\"',c,flags=re.M))"
./deploy-backend.sh 2>&1 | head -3       # expect: "Key does not match..."
cp /tmp/env.backup .env

# T2: missing key must hard-fail
python3 -c "import re; c=open('.env').read(); open('.env','w').write(re.sub(r'^CONVEX_DEPLOYMENT_PROD=.*$','',c,flags=re.M))"
./deploy-backend.sh 2>&1 | head -3       # expect: "CONVEX_DEPLOYMENT_PROD not set"
cp /tmp/env.backup .env

# T3: CRLF key must still pass (be stripped)
python3 -c "c=open('.env','rb').read(); open('.env','wb').write(c.replace(b'|<last-char-of-token>\"', b'|<last-char-of-token>\r\"'))"  # adjust byte match
./deploy-backend.sh 2>&1 | head -6       # expect: proceeds past format check

# T4: shell shadowing defeated
CONVEX_DEPLOYMENT_PROD="prod:attack|fake" ./deploy-backend.sh 2>&1 | head -3   # expect: script reads .env, NOT shell

# T5: detached HEAD
git checkout --detach HEAD --quiet && ./deploy-backend.sh 2>&1 | head -3 && git checkout main --quiet
# expect: "Detached HEAD"

cp /tmp/env.backup .env
```

If any test gives unexpected output → gate is not enforcing, stop and compare against the canonical template.

### Per-repo state audit (list all your repos)

```bash
for repo in ~/Code/*/deploy-backend*.sh; do
  printf "\n=== $(dirname "$repo" | xargs basename) ===\n"
  grep -c 'EXPECTED_DEPLOYMENT' "$repo"
done
```

A `0` means the repo has never had the v1 hardening and MUST NOT be used to deploy until retrofitted. `1+` means v1 is in — then run the fast audit above for v2 status.
