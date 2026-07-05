---
paths:
  - "**/deploy*.sh"
  - "**/Makefile"
  - "**/.github/workflows/**"
  - "**/convex.json"
  - "**/modal.toml"
  - "**/vercel.json"
  - "**/.modal.toml"
---

# Deploy Safety Rules

> Codified from the lanalyzer-overwrite incident (2026-04-19, svb-manager).
> Incident background, canonical deploy-script template, retrofit checklist,
> sabotage tests, and per-repo audit script: `~/.claude/runbooks/deploy-safety-postmortem.md`.

## The 10-Gate Checklist for Every Deploy Script

A deploy script is only safe when ALL 10 gates pass. Fail any one → exit 1 before touching any remote service.

1. **Project-scoped env var names.** Forbidden: `CONVEX_PROD_DEPLOY_KEY`, `CONVEX_DEPLOY_KEY`, `DEPLOY_KEY`. Required: `CONVEX_DEPLOYMENT_PROD`, `MYPROJECT_CONVEX_PROD_KEY`, etc. Generic names get populated by shell exports from other projects.
2. **Read keys from `.env`, never from shell environment.** Use `grep`/`sed` from project's `.env`, not `${ENV_VAR}` lookup. Path anchored to script location, never `$CWD`. Code template in postmortem runbook.
3. **Hard-fail when key is absent.** `[[ -z "$KEY" ]] && { echo "ERROR …" >&2; exit 1; }`.
4. **Target-prefix check (hardcoded `EXPECTED_DEPLOYMENT` constant).** Assert `[[ "$KEY" == "prod:${EXPECTED_DEPLOYMENT}|"* ]]` before `npx convex deploy`. Last line of defense even if Gate 2 is bypassed.
5. **Separate scripts for prod vs dev.** No `--env` switching. Use `deploy-backend.sh` / `deploy-backend-dev.sh`, each with own hardcoded `EXPECTED_DEPLOYMENT`.
6. **`docs/ENV.md` must exist** and list expected deployment names (Convex Prod + Dev). Script's `EXPECTED_DEPLOYMENT` constant must match.
7. **No `source .env` in deploy scripts.** Use targeted `grep` to extract only the specific key needed. `source` re-creates the cross-project shadowing problem.
8. **Dry-run / echo-before-act.** `echo "Deploying to Convex: ${EXPECTED_DEPLOYMENT} …"` before the deploy command.
9. **Never commit `.env` with deploy keys.** `.gitignore`d. Commit `.env.example` with placeholders.
10. **Post-deploy verification.** `npx convex env list 2>/dev/null | head -5` after deploy. If output doesn't reference expected deployment → alert and recommend rollback from git tag.

Bash code templates for each gate: postmortem runbook (link above).

## Lint Rule for Agents (Convex deploy scripts)

When reviewing any deploy script (`.sh`, `Makefile`, `package.json` scripts, GitHub Actions workflows), flag as **CRITICAL** if:

- Reference to `CONVEX_PROD_DEPLOY_KEY` or `CONVEX_DEPLOY_KEY` (generic names)
- `source .env` in a deploy context
- No hardcoded `EXPECTED_DEPLOYMENT` constant with prefix check
- Key read from `${ENV_VAR}` without `.env` grep fallback check

Flag as **WARNING** if:
- No `docs/ENV.md` exists
- No post-deploy verification step
- Prod and dev scripts combined into one file

## Modal Lint Rule for Agents

When reviewing any Modal deploy script (`.py` or shell wrapper invoking `modal deploy`), flag as **CRITICAL** if:

- `modal deploy` invoked without a hardcoded app-name constant (e.g. `MODAL_APP_NAME=lanalyzer-prod`) — generic `modal deploy` is the Modal equivalent of Convex's wrong-instance footgun
- No branch guard for prod (prod deploy from non-`main` branch must exit 1)
- Token verification absent: script must call `modal token current` and assert workspace matches a hardcoded constant before deploying
- `modal.Secret.from_name(...)` references generic names that could collide with other projects (e.g. `convex-prod` instead of `lanalyzer-convex-prod`)

Flag as **WARNING** if:
- Modal CLI not installed/authenticated check missing (script silently no-ops)

> **Out of scope (separate plan):** Modal post-deploy verification command (Convex equivalent: Gate 10). Modal canonical template + retrofit checklist parallel to runbook.

## Vercel must not hold Convex or Modal deploy keys

Vercel deploys automatically on `git push`. Convex and Modal are deployed manually (Golden Rule #7). Therefore:

- `vercel env` (production AND preview) must NOT contain `CONVEX_DEPLOY_KEY`, project-scoped `CONVEX_DEPLOYMENT_PROD` / `CONVEX_DEPLOYMENT_DEV`, or `MODAL_TOKEN`. The Vercel build path has no business invoking `npx convex deploy` / `modal deploy` — that is the deploy script's job, run from a developer's machine.
- Vercel only needs read-only client config: `NEXT_PUBLIC_CONVEX_URL`, `NEXT_PUBLIC_CONVEX_SITE_URL`, public app URLs.
- **Lint flag:** any of the forbidden keys present in `vercel env ls` for a project that also has `convex/` or Modal → **HIGH**.

## Open Risk: Globally Exported Deploy Secrets in ~/.zshrc

`~/.zshrc` historically exported `CONVEX_PROD_DEPLOY_KEY`, `CONVEX_DEV_DEPLOY_KEY`, and `VERCEL_TOKEN` globally. Any deploy script that reads via `${CONVEX_PROD_DEPLOY_KEY}` instead of grepping its `.env` will silently target the wrong project. The 10-gate contract above defeats this at the project level — but the shell exports remain a latent footgun until removed manually.
