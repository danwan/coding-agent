# Known Issues — Claude Code Runtime

Known bugs in Claude Code that affect our work. This file is referenced from the global CLAUDE.md.

---

## 1. Top-Level `hooks/` Directory Is Automatically Deleted

**Status:** Open — deletion aspect NOT reproducible in daily use under v2.1.101 (re-verify on regression)
**Tracking:** [anthropics/claude-code#34330](https://github.com/anthropics/claude-code/issues/34330) (auto-closed 2026-03-18 as duplicate of #33733 by github-actions bot, not confirmed fixed by Anthropic; no CHANGELOG entry)
**Discovered:** 2026-03-28, SVB Manager Phase 1
**Last verified:** 2026-04-11, CC v2.1.101 — primary evidence: `/Users/dannywannagat/Code/n8n/.claude/skills/` has 7 project skills (directory-per-skill layout with SKILL.md) that have persisted since 2026-03-26 in daily use and are correctly shown under "Project skills" in `/skills`. No deletion, no discovery failure. A synthetic canary test was also run but is not treated as authoritative because the sandbox profile may have been inherited by the headless child session, potentially suppressing unlink() calls. Treat as latent — restore the `lib/hooks/` workaround if deletion returns.

**Symptom:** A top-level `hooks/` directory in a project is automatically deleted from disk ~5-10 seconds after creation. Files exist in Git but disappear from the filesystem. `git status` shows `deleted: hooks/*`.

**Root Cause:** Claude Code's runtime has an internal cleanup mechanism that automatically removes certain top-level directory names. Affects at least:
- `hooks/` (confirmed)
- `.claude/skills/` (Issue #34330)

**Workaround:** Move hooks into a subdirectory:
```
hooks/use-session.ts  →  lib/hooks/use-session.ts
```
Adjust imports accordingly: `@/hooks/...` → `@/lib/hooks/...`

**Not affected:** `lib/hooks/`, `src/hooks/`, `components/`, `convex/lib/` — only top-level `hooks/` is the problem.

---

## 2. ExitPlanMode Hook Race Condition — Intermittent Block After Plan Mode Exit

**Status:** Resolved 2026-04-11 — `enforce-plan-mode.sh` hook removed entirely. Root cause was a CC-runtime race that sent stale `permission_mode="plan"` to the `PreToolUse` hook after `ExitPlanMode`. On 2026-04-11 a second variant appeared where the stale status persisted for the whole session (not self-healing on retry), blocking all subsequent writes. Empirical test in a clean session (plan doc: `zz-plans/jiggly-moseying-snowglobe.md`) confirmed that CC 2.x's native plan-mode system prompt already enforces the constraint reliably at the agent level — the agent refused a direct write request AND refused an explicit user override instruction, citing the plan-mode reminder as a "system-level constraint". Defense-in-depth via the hook was redundant; removing it fixes both the original race and the 2026-04-11 persistence variant. Script file and `PreToolUse` hook registration both deleted.

**Discovered:** 2026-03-29, Config-Sync Session
**Resolved:** 2026-04-11, Hook-Review Session

**Historical symptom (kept for reference):** After `ExitPlanMode`, parallel Write/Edit calls were dispatched. One or more of them were blocked by the `enforce-plan-mode.sh` hook with:
```
BLOCKED: Edit on ... - Plan mode is active. Use ExitPlanMode to request permission.
```
Even though ExitPlanMode was already called.

---

## 4. Cross-Project Convex Deploy via Shell-Exported Key — "Wrong Instance" Footgun

**Status:** Currently absent (verified 2026-04-30, this machine — Shell-Init-Files + `launchctl getenv` geprüft, keine der drei Exports gefunden). svb-manager-Hardening (2026-04-19) bleibt als Defense-in-Depth gegen Re-Introduktion.
**Discovered:** 2026-04-19, svb-manager prod deploy session

**Symptom:** `./deploy-backend.sh` silently deploys to the WRONG Convex instance. No error. The wrong project's schema + functions are overwritten. First visible sign: unexpected env vars or function names on the "deployed" instance.

**Immediate red flag to recognize:** After a deploy, if you see env var names or function names from a DIFFERENT project on the target Convex dashboard → stop. You are on the wrong instance. Do NOT rationalize these as "old cleanup artifacts." Treat cross-project artifacts as a stop signal and investigate before proceeding.

**Root Cause:** `~/.zshrc` contains `export CONVEX_PROD_DEPLOY_KEY="prod:adorable-chipmunk-536|…"` (lanalyzer's key). Any deploy script that reads the key via `${CONVEX_PROD_DEPLOY_KEY}` shell expansion instead of `grep`-ing from the project's `.env` will use lanalyzer's key silently.

**Current global state (2026-04-19, historisch — am 2026-04-30 nicht mehr in den geprüften Locations gefunden, this machine):** `~/.zshrc` exported at the time:
- `CONVEX_PROD_DEPLOY_KEY` → `prod:adorable-chipmunk-536` (lanalyzer's prod)
- `CONVEX_DEV_DEPLOY_KEY` → `dev:acrobatic-guineapig-733` (lanalyzer's dev)
- `VERCEL_TOKEN` → cross-project Vercel token

**Fix applied in svb-manager:**
1. Renamed env vars to project-scoped names (`CONVEX_DEPLOYMENT_PROD`)
2. Script reads key via `grep` from `.env` — no shell-var fallback
3. Hard target-prefix check: `[[ "$KEY" == "prod:${EXPECTED_DEPLOYMENT}|"* ]]` before any deploy

**Status 2026-04-30:** Auf dieser Maschine nicht mehr gefunden. Bei dotfile-Sync von einer anderen Maschine erneut prüfen (Live-Check via `grep -nE 'CONVEX_(PROD|DEV)?_DEPLOY_KEY|VERCEL_TOKEN' ~/.zshrc` + `launchctl getenv CONVEX_PROD_DEPLOY_KEY`).

**How to recognize the footgun in code review:** Any deploy script containing `${CONVEX_PROD_DEPLOY_KEY}` or `${CONVEX_DEPLOY_KEY}` without a `grep .env` fallback is vulnerable. Flag CRITICAL.

**Full post-mortem and 10-gate checklist:** `~/.claude/rules/deploy-safety.md`

---

## 3. Sandbox Blocks Write Access to `.git/config`

**Status:** By design (sandbox restriction)
**Discovered:** 2026-03-29, SVB Manager push

**Symptom:** `git remote add` or `gh repo create --push` fails with:
```
error: could not write config file .git/config: Operation not permitted
```

**Root Cause:** The sandbox allows writes to the project directory but `.git/config` is separately protected, so `git remote add` / `gh repo create --push` can fail even though HTTPS (our standard transport) is otherwise sandbox-friendly.

**Workaround:** Run git-remote operations with `dangerouslyDisableSandbox`:
```bash
gh repo create <name> --private --source=. --push   # sets HTTPS remote
# if that still fails on .git/config, rerun with dangerouslyDisableSandbox
```

**Note (since v2.1.113):** The `dangerouslyDisableSandbox` call now correctly triggers a permission prompt (previously: silent — a security bug). The workaround still works, but the prompt must be confirmed once per call.

**Affects:** All `git remote` / `git config` write operations inside the sandbox.
