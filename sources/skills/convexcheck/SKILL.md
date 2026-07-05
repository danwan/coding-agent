---
name: convexcheck
description: Audit the current project's deploy setup (Convex + Vercel + Modal + shell) for the footguns documented in ~/.claude/rules/deploy-safety.md. Strict report-only — no fixes applied.
disable-model-invocation: true
---

# convexcheck

Runs a full deployment-safety audit on the project in the current working
directory. Reports every gate as ✅ / ❌ / ⚠️ with evidence (`file:line` or
command output). **Does not apply any fixes** — the user reviews findings
and decides per item.

This skill is **explicit-only** (`disable-model-invocation: true`) — it never auto-triggers. Invoke when the user types `/convexcheck`, asks for a deploy-safety audit, finishes onboarding on a new machine, prepares a first production deploy, or modifies a deploy script.

## Usage

- `convexcheck` — full audit of the current project.
- `convexcheck --fix-suggestions` — same audit, plus ready-to-paste diffs/
  file contents for each ❌. Still no auto-apply.

## Background: why this exists

On 2026-04-19, svb-manager's `./deploy-backend.sh` silently deployed to
lanalyzer's Convex prod instance because `~/.zshrc` globally exported
`CONVEX_PROD_DEPLOY_KEY` pointing at lanalyzer, and svb-manager's deploy
script fell back to the shell var when its `.env` had no key. No target-
match check existed. The wrong project's schema + functions got overwritten.

10-gate contract + lint rule: **`~/.claude/rules/deploy-safety.md`**.
Full post-mortem, canonical deploy-script template, retrofit checklist:
**`~/.claude/runbooks/deploy-safety-postmortem.md`**. Read both first.

## What the audit checks

### A. Secret isolation (nothing sensitive in git)

1. `.gitignore` covers env files. Pattern must match `.env`, `.env.local`,
   `.env.production`. If pattern is `.env*`, a `!.env.example` exception
   MUST exist when a template file is present.
2. No env files tracked right now:
   `git ls-files .env .env.local .env.production` → empty.
3. No env file ever committed in history:
   `git log --all --full-history --oneline -- .env .env.local .env.production`
   → empty.
4. No deploy-key strings in any tracked file:
   `git grep -IE '(prod|dev):[a-z0-9-]+\|eyJ' -- ':!*.lock' ':!*lock.json' ':!*lock.yaml'`
   → empty.
5. `convex/_generated/` tracked files contain only TypeScript bindings, no
   `eyJ2MiI…` base64 patterns.
6. If `.github/workflows/*`, `.gitlab-ci.yml`, `.circleci/config.yml`, or
   similar CI config exists, verify secrets come from the CI secret store
   (syntax: `${{ secrets.FOO }}` / `$CI_*`), never from committed files.

### B. Deploy script hygiene (prevents cross-project bleed)

Find every deploy script: `deploy*.sh`, Makefile `deploy:` targets,
`package.json` scripts matching `deploy*`, CI deploy steps. For EACH:

1. **Project-scoped var names.** Generic names are FORBIDDEN:
   ```bash
   grep -rnE 'CONVEX_(PROD_|DEV_)?DEPLOY_KEY|CONVEX_DEPLOY_KEY(?!_)' \
     --include='*.sh' --include='Makefile' --include='*.yml' \
     --include='*.yaml' --include='package.json' .
   ```
   Any hit in a deploy context → **CRITICAL**. Allowed names: project-scoped
   like `CONVEX_DEPLOYMENT_PROD`, `<PROJECT>_CONVEX_PROD_KEY`.

2. **Keys read from `.env` via `grep`**, never shell expansion. Forbidden:
   ```bash
   source .env
   set -a; source .env; set +a
   KEY="${CONVEX_DEPLOYMENT_PROD}"   # inheriting from shell
   ```
   Correct:
   ```bash
   KEY=$(grep '^CONVEX_DEPLOYMENT_PROD=' .env | cut -d'=' -f2- | sed 's/^"//; s/"$//')
   ```

3. **Hard-fail on empty key** with actionable error (must name the exact var
   + generate URL).

4. **Target-prefix check BEFORE any deploy**:
   ```bash
   EXPECTED_DEPLOYMENT="<convex-instance-id>"   # hardcoded, not from .env
   [[ "$KEY" == "prod:${EXPECTED_DEPLOYMENT}|"* ]] || { echo "wrong target"; exit 1; }
   ```
   `EXPECTED_DEPLOYMENT` must be a hardcoded string, and match the value in
   `docs/ENV.md`.

5. **Separate prod vs dev scripts.** One script with `--env` flag switching
   is a smell. Each script gets its own `EXPECTED_DEPLOYMENT` constant.

6. **Branch guard for prod**: refuse deploy if not on `main`.

7. **Clean-tree check for prod**: refuse deploy with uncommitted / untracked
   files (`git diff --quiet && git diff --cached --quiet` + untracked check).

8. **Sync check for prod**: `git fetch origin main` + assert
   `HEAD == origin/main`.

9. **Tests run before deploy** (`npm test`, `pytest`, etc.) with fail-on-
   error. `SKIP_LINT=1` style escape hatches OK for lint; tests should not
   be skippable.

10. **Target logged BEFORE deploy call**:
    `echo "=== Deploying Convex (Production: ${EXPECTED_DEPLOYMENT}) ==="`

### C. Onboarding template

1. A `.env.example` (or `.env.template` / `.env.sample`) exists.
2. Every `process.env.FOO` the code reads AND every `grep -E '^FOO=' .env`
   the scripts read appears in the template, with placeholder values + a
   "generate at: …" hint.
3. Cross-check:
   ```bash
   grep -rhoE 'process\.env\.[A-Z_]+' --include='*.ts' --include='*.tsx' --include='*.js' . | sort -u
   grep -rhE "^[A-Z_]+=" .env.example 2>/dev/null | cut -d= -f1 | sort -u
   ```
   Symmetric difference → findings.
4. Template contains NO real secrets. Any entry matching `prod:xxx|eyJ` is a
   leak → **CRITICAL**. Placeholders use `REPLACE_WITH_…` or empty string.

### D. docs/ENV.md parity

1. `docs/ENV.md` (or equivalent) exists and lists Convex prod + dev
   deployment names + cloud URLs.
2. Deployment names in `docs/ENV.md` match every `EXPECTED_DEPLOYMENT`
   constant in the deploy scripts. Mismatch → **CRITICAL**.
3. Documents Vercel env-var soll-zustand (production + preview
   `NEXT_PUBLIC_CONVEX_URL`, `NEXT_PUBLIC_CONVEX_SITE_URL`).
4. Warns that Vercel must NOT receive a Convex deploy key (per Golden
   Rule #12 — Convex is deployed manually, not via Vercel build).

### E. Vercel configuration

If `vercel` CLI is authenticated and the project is linked (`.vercel/`
directory present):

1. Run `vercel env ls 2>&1 | head -60` — list names only (values are
   masked by default). Check:
   - Production has `NEXT_PUBLIC_CONVEX_URL`, `NEXT_PUBLIC_CONVEX_SITE_URL`,
     and any `NEXT_PUBLIC_APP_URL` the code uses.
   - Vercel does **NOT** have `CONVEX_DEPLOY_KEY` or project-scoped deploy
     keys set. If it does → **HIGH** (breaks Golden Rule #7).
2. Preview env vars must NOT be pinned to a single branch. Output shows
   `(Branch: <name>)` after pinned vars — flag any pinned preview var as
   **MEDIUM** (other preview branches build without Convex URL).
3. If `vercel` CLI not linked, report as ⚠️ with the manual command for
   the user to run.

### F. Convex Cloud env-var sanity

For each `EXPECTED_DEPLOYMENT` in the deploy scripts:

1. Pull key names ONLY (avoid dumping secrets to transcript):
   ```bash
   KEY=$(grep '^CONVEX_DEPLOYMENT_PROD=' .env | cut -d= -f2- | sed 's/^"//; s/"$//')
   CONVEX_DEPLOY_KEY="$KEY" npx convex env list 2>/dev/null | cut -d'=' -f1 | sort
   ```
2. Extract every `process.env.FOO` the Convex backend code reads:
   ```bash
   grep -rhoE 'process\.env\.[A-Z_]+' convex/ | grep -oE '[A-Z_]+$' | sort -u
   ```
3. Vars read by code but missing in Convex Cloud → **HIGH** (runtime
   behavior broken). Vars set in Convex Cloud but never read by code →
   **LOW** (possible stale config, may belong to a different project → big
   footgun signal, flag the list separately).
4. `NEXT_PUBLIC_*` vars read server-side in `convex/` must be set in Convex
   Cloud AND in Vercel (browser bundle).

### G. Shell-export leak (the original footgun)

Scan user's shell profile for forbidden generic exports:
```bash
grep -HnE 'export CONVEX_(PROD_|DEV_)?DEPLOY_KEY=|export CONVEX_DEPLOY_KEY=|export MODAL_TOKEN=|export VERCEL_TOKEN=' \
  ~/.zshrc ~/.bashrc ~/.zprofile ~/.bash_profile 2>/dev/null
```
Any hit → **HIGH** (next project's deploy script that reads via shell
expansion will target whichever project this key belongs to). Report file
+ line + the deployment name the key points to, recommend removal with
exact `sed -i` hint.

### H. Modal deploy hygiene (if applicable)

If the repo has `app.py` with `@stub.function` / `modal.App` declarations OR
contains `modal deploy` in any script:

1. Modal deploy script has a project-scoped app name constant (e.g.
   `MODAL_APP_NAME=lanalyzer-prod`), not a generic `modal deploy` alone.
2. Branch guard for prod: `modal deploy` for prod only on `main`.
3. Modal token verification before deploy: `modal token current` output
   matches expected workspace (hardcoded constant in script).
4. Secret-name allowlist: the `modal.Secret.from_name(...)` references in
   `app.py` all point to project-scoped secret names (not generic names
   like `convex-prod` that could belong to any project).
5. If `modal` CLI not installed / not authenticated, report as ⚠️.

## Output format

Per section A-H, list:
- `✅ passed` with 1-line evidence
- `❌ failed (evidence: <file:line or command-output-snippet>)` + concrete fix
- `⚠️ partial / skipped (reason: …)`

For every ❌: a concrete fix as EITHER a diff block (for existing files)
OR a fenced ```new-file``` block (for missing files). NOT vague advice.

At the end, a ranked summary:
- **CRITICAL** — blocks safe deploy, must fix before any deploy call
- **HIGH** — real risk of an incident (e.g. misconfigured shell export)
- **MEDIUM** — hygiene, would bite eventually
- **LOW** — nice-to-have

## Guard rails

- **Never echo `.env` contents or `npx convex env get <name>` values to the
  transcript.** Always use `cut -d= -f1` or similar to extract names only.
- **Never run `npx convex deploy`** as part of the audit.
- **Never edit files** unless the user invoked `--fix-suggestions` AND
  explicitly approved a specific finding afterwards. Even then, apply
  one fix at a time with user confirmation.
- If a check requires a command that the sandbox blocks, report the manual
  command the user should run instead — do not bypass sandbox for audit.

## Action

1. Announce: "Using convexcheck to audit deploy setup per
   `~/.claude/rules/deploy-safety.md`. Report-only."
2. Read `~/.claude/rules/deploy-safety.md` to refresh the gate list.
3. Run sections A-H in order, producing findings as you go.
4. Print the ranked summary at the end.
5. If `--fix-suggestions` was passed, generate fix content per finding but
   don't apply.
6. Offer to follow up on any CRITICAL or HIGH finding — wait for user
   direction. Do NOT proactively apply fixes.
