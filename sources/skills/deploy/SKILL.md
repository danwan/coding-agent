---
name: deploy
description: Safe Modal/Convex backend deployment. Delegates to the project's ./deploy-backend.sh and ./deploy-backend-preview.sh scripts — those scripts own the 10-gate safety contract from ~/.claude/rules/deploy-safety.md. This skill routes to the right one, handles dirty state, and refuses to fall back to unsafe manual commands. Use when user says "deploy", "push to production", "modal deploy", "convex deploy", "deploy backend".
allowed-tools: Bash, Read, Grep, Glob
disable-model-invocation: true
version: 2.0.0
---

# Deploy Skill

Routes to the project's hardened deploy scripts. The scripts own the gates; this skill ensures the working tree is deploy-ready and invokes the correct one.

**Invocation is the intent signal.** Per user preference — do NOT ask for confirmation. `/deploy` means deploy.

**Never fall back to manual `npx convex deploy` with shell-expanded keys.** That is the exact anti-pattern that caused the 2026-04-19 cross-project-deploy incident. If the project has no hardened deploy script, STOP and point to the canonical template.

---

## Prerequisites (verified every run)

1. Project has `./deploy-backend.sh` (production) and `./deploy-backend-preview.sh` (development) in the repo root.
2. Project has `docs/ENV.md` listing Convex prod + dev deployment names and Modal app names.
3. Each script hardcodes `EXPECTED_DEPLOYMENT` matching `docs/ENV.md`.
4. Scripts read deploy keys from `.env` via `grep` (never `source .env`, never `${VAR}` shell expansion).

If any of these is missing → HARD STOP (see "Hard Stops" below). Do not improvise.

---

## Workflow

### 1. Locate scripts

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
test -x "$PROJECT_ROOT/deploy-backend.sh" || HARD_STOP=1
test -x "$PROJECT_ROOT/deploy-backend-preview.sh" || HARD_STOP=1
```

If either is missing → see "Hard Stops → No deploy scripts".

### 2. Determine target branch

```bash
BRANCH=$(git branch --show-current)
```

- `BRANCH = main` → production path (`./deploy-backend.sh`)
- `BRANCH ≠ main` → development path (`./deploy-backend-preview.sh`)

### 3. Make working tree deploy-ready

The project's prod script enforces clean-tree + sync-with-origin itself. This step removes friction so those gates pass on first try instead of after a cycle of "script failed because dirty, commit, try again."

```bash
git fetch origin --quiet

# Check sync
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse "origin/$BRANCH" 2>/dev/null || echo "none")
BASE=$(git merge-base HEAD "origin/$BRANCH" 2>/dev/null || echo "none")

if [[ "$REMOTE" = "none" ]]; then
  # Branch not on remote yet — will push in step 4
  true
elif [[ "$LOCAL" = "$REMOTE" ]]; then
  true  # in sync
elif [[ "$LOCAL" = "$BASE" ]]; then
  # Local is behind remote — fail clearly (do not auto-pull; user may have local commits to rebase)
  echo "ERROR: Local branch is behind origin/$BRANCH. Run: git pull --rebase origin $BRANCH" >&2
  exit 1
elif [[ "$REMOTE" = "$BASE" ]]; then
  true  # local is ahead — will push in step 4
else
  echo "ERROR: Local and origin/$BRANCH have diverged. Resolve manually before deploying." >&2
  exit 1
fi
```

Then: if dirty or ahead-of-remote, commit and push.

```bash
if [[ -n "$(git status --porcelain)" ]]; then
  # Analyze changes, generate concise commit message
  git add -A
  git commit -m "<generated from diff>"
fi

# Push if ahead or branch is new on remote
git push -u origin "$BRANCH"
```

Commit message: 1-2 sentences, English, focused on the "why". Follow the repo's existing commit style (check `git log -5 --oneline`).

### 4. Invoke the hardened script

```bash
# On main
./deploy-backend.sh

# On feature branch
./deploy-backend-preview.sh
```

**Do not wrap, proxy, or modify the script's behavior.** The script's own output is the deploy record. If the script exits non-zero, report which gate failed (the error message will name it) and stop — do NOT retry, do NOT suggest "add `--force`" or similar.

**Sandbox note (Claude Code):** Modal + `uv` need the sandbox disabled for cache access. Convex CLI does too. Run the deploy script with `dangerouslyDisableSandbox: true`.

### 5. Post-deploy report

The scripts already log the target deployment + run `npx convex env list` after deploy. Surface that output to the user — don't summarize it away.

For production deploys only, add a brief reminder at the end:

> Production deploy complete. Monitor error logs for 15 min. Vercel rollback if needed: `vercel rollback`.

---

## Hard Stops (no improvised fallback)

### No deploy scripts in the repo

```
ERROR: This project has no ./deploy-backend.sh or ./deploy-backend-preview.sh.

Do NOT deploy manually via `npx convex deploy` with shell-expanded keys
(e.g. `CONVEX_DEPLOY_KEY="$CONVEX_PROD_DEPLOY_KEY" npx convex deploy`).
That is the exact anti-pattern that caused the 2026-04-19 cross-project-deploy
incident — a shell export from another project silently redirected the deploy.

Create the scripts per the canonical template:
  ~/.claude/runbooks/deploy-safety-postmortem.md → "Reference: Canonical Deploy Script Template"
(Enforceable rule + 10-gate contract: ~/.claude/rules/deploy-safety.md)

The template enforces all 10 gates:
  1  project-scoped env var names          6  branch guard
  2  grep key from .env (not shell)        7  clean-tree check
  3  hard-fail on empty key                8  sync with origin
  4  EXPECTED_DEPLOYMENT prefix check      9  lint + tests
  5  separate prod vs dev scripts         10  target echo + post-deploy verify
```

Refuse to proceed. Ask the user if they want help creating the scripts from the template — that is a separate task, not part of /deploy.

### Script references forbidden patterns (spot-check before running)

Before invoking a script, spot-check for the anti-patterns from `~/.claude/rules/deploy-safety.md`. Uses `awk` so that preventative comments like `# don't use source .env` do NOT trigger a false positive (`grep -nE` with a negative-prefix regex fails because the prefix consumes the first character of the forbidden pattern):

> **Pattern sync with rules file.** The 3 patterns here (`source .env`, `${CONVEX_(PROD|DEV)?_DEPLOY_KEY}`, `^CONVEX_(PROD|DEV)_DEPLOY_KEY=`) are a strict subset of the CRITICAL list in `~/.claude/rules/deploy-safety.md` (section "Lint Rule for Agents"). **Source of truth is the rules file.** Sync both places when updating patterns. The rules file contains additional items (missing `EXPECTED_DEPLOYMENT`, missing `docs/ENV.md`, missing post-deploy verification, combined prod/dev scripts) that aren't expressible via awk and remain agent-side checks only.

```bash
awk '
  /^[[:space:]]*#/ { next }
  /source \.env/                                 { print FILENAME":"NR": "$0 }
  /\$\{?CONVEX_(PROD|DEV)?_DEPLOY_KEY\}?/        { print FILENAME":"NR": "$0 }
  /^[[:space:]]*CONVEX_(PROD|DEV)_DEPLOY_KEY=/   { print FILENAME":"NR": "$0 }
' deploy-backend.sh deploy-backend-preview.sh
```

Any hit → refuse to run. Tell the user:

> Your deploy script contains a pattern banned by ~/.claude/rules/deploy-safety.md.
> Specific match: [file:line]
> Run `/convexcheck` for a full audit before deploying.

This is a quick lint, not a full audit. `/convexcheck` is the comprehensive check.

### Diverged branch

Step 3 catches this. Never auto-merge or auto-rebase. Hand the decision back to the user.

### Prod script called from non-main branch

The script itself enforces this (Gate 6). Don't try to auto-checkout main — that could discard uncommitted work on the current branch.

### Dev script called from main

The script prompts interactively. If invoked by Claude non-interactively, the prompt will just fail. Answer: tell the user "you're on main — use `./deploy-backend.sh` for production, or checkout a dev branch first."

---

## What This Skill Does NOT Do

- **Does not duplicate the script's gates.** The script runs lint + tests + prefix check. This skill does not pre-run them.
- **Does not ask for confirmation.** `/deploy` is the confirmation.
- **Does not offer `--force` / `--skip-tests` / "hotfix mode".** If a gate fails, fix the underlying issue.
- **Does not deploy via manual CLI commands** if the script is missing. See "Hard Stops".
- **Does not manage Vercel env vars.** Vercel deploys automatically on `git push` (Golden Rule #4). Env-var CRUD is separate — use `vercel env` CLI commands directly per `docs/ENV.md`.
- **Does not rename Convex Preview deployments** — feature branches share a single Convex dev instance in most projects. Two parallel dev deploys race each other; the last one wins. The user should know this. Not this skill's job to prevent.

---

## Feature-Branch Note (Convex Dev Instance is Shared)

Most projects in this setup use ONE Convex dev instance (`dev:…`) for all feature branches. There are no per-branch Convex Preview deployments. If two contributors run `./deploy-backend-preview.sh` simultaneously, the last one wins.

If the user deploys two branches back-to-back and expects each to have its own Convex state, surface this: "Both deploys went to the same dev instance — branch N overwrote branch N-1's schema."

---

## Trigger Examples

| User says | Path |
|-----------|------|
| "deploy" | Determine branch, run matching script |
| "push to production" | Require `BRANCH = main`, run `./deploy-backend.sh` |
| "deploy backend" | Same as "deploy" |
| "deploy to dev" / "deploy preview" | Run `./deploy-backend-preview.sh` regardless of branch (but script's own guard will warn on main) |
| "convex deploy" | Route to this skill — do NOT run `npx convex deploy` directly |
| "modal deploy" | Route to this skill — do NOT run `modal deploy` directly |

---

## Version History

- **2.0.0** (2026-04-19): Rewritten after the 2026-04-19 svb-manager→lanalyzer cross-project-deploy incident. Removed all shell-expanded-key fallbacks. Removed confirmation dialog (per user memory). Gates now owned by project scripts; skill only routes. Hard-stops instead of unsafe improvisation.
- **1.0.0**: Initial version with embedded confirmation + manual-command fallbacks (both deprecated).
