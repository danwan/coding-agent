---
name: convex-vercel-setup
description: Standardize, audit, scaffold, and migrate Vercel + Convex + optional Modal deployment configuration. Use when setting up new Convex-backed Vercel projects, fixing production/preview env mappings, creating deploy manifests/scripts, or migrating existing projects to the standard framework.
---

# Convex + Vercel Setup

Use this skill to make Convex/Vercel/Modal projects reproducible without asking
an LLM to remember per-project details.

## Core Rule

Start from local evidence, then scripts:

```bash
cd <project>
/Users/dannywannagat/Code/coding-agent-setup/scripts/convex-vercel/cvv-setup.sh --status
```

Do not infer that a project uses Convex, Modal, Next.js, or Vercel. Verify the
repo first. Do not print secrets. Do not put deploy keys in Vercel.

## Standard Profiles

- `direct-convex`: Browser uses Convex directly. Every public Convex
  `query`, `mutation`, and `action` must enforce auth/session or be explicitly
  documented as public.
- `server-proxy`: Browser calls Next.js API routes. Core Convex functions are
  `internal*`; Convex HTTP actions are guarded by a shared server-side secret.
- `modal-proxy`: Same as `server-proxy`, plus Modal services. Modal app names
  and Modal secret names must be project-scoped for prod and preview.

Default for internal tools: `server-proxy`. Default preview model:
`shared-dev` Convex deployment for all non-`main` Vercel previews. Use
per-branch Convex only when data isolation is worth the extra operations.

## Scripts

All scripts are dry-run/read-only unless explicitly marked otherwise.

```bash
SETUP=/Users/dannywannagat/Code/coding-agent-setup/scripts/convex-vercel

$SETUP/cvv-setup.sh --project <project>
$SETUP/cvv-audit.sh --project <project>
$SETUP/cvv-doctor.sh --project <project> --target all
$SETUP/cvv-scaffold.sh --project <project> --profile server-proxy
$SETUP/cvv-env-plan.sh --project <project> --env production --target all
$SETUP/cvv-env-plan.sh --project <project> --env preview --target all
$SETUP/cvv-env-apply.sh --project <project> --env preview --target vercel
$SETUP/cvv-env-apply.sh --project <project> --env preview --target vercel --secrets-file <project>/.deploy/secrets.env --apply
$SETUP/cvv-secrets.sh --project <project> --env all --generate-missing --apply
```

`cvv-env-apply.sh` writes cloud env vars only with `--apply`. It supports Vercel
and Convex, including `--target all`. For apply, use `--secrets-file`; prompt or
sensitive values must already be in the local gitignored secrets file. This
prevents partial cloud writes and avoids asking a user or LLM to handle secret
values interactively. Modal remains plan-only because Modal secret grouping is
project-specific.

## Required Project Contract

Each active Convex project should have:

- `docs/deployment.config.json`: machine-readable source for deployment names,
  URLs, app roots, env vars, profile, and forbidden Vercel keys.
- `docs/ENV.md`: human-readable deployment mapping.
- `.env.example`: placeholders only, no real values.
- `.env`: optional local-only Convex deploy keys, gitignored.
- `.deploy/secrets.env`: local-only generated secrets, gitignored and chmod
  600. The scripts refuse to generate or apply this file when Git would track
  it. Agents may refer to this path but must not print values. Convex deploy
  keys may also live here. They are not URLs and must never be put in Vercel.
  `cvv-secrets.sh --apply` adds commented deploy-key placeholders so humans can
  uncomment the right names and paste Dashboard tokens without inventing names.
- `scripts/cloud-env.sh`: project wrapper around the central setup scripts.
  It stays thin and supports `./scripts/cloud-env.sh setup`.
- `deploy-backend.sh`: production Convex deploy, hardcoded prod deployment,
  main-branch and clean-tree gates.
- `deploy-backend-preview.sh`: shared dev/preview Convex deploy, hardcoded dev
  deployment, refuses `main`.

## Workflow

1. Start the guided wizard from the project root:
   ```bash
   $SETUP/cvv-setup.sh
   ```
   Or after scaffold:
   ```bash
   ./scripts/cloud-env.sh setup
   ```
2. Audit:
   ```bash
   $SETUP/cvv-audit.sh --project <project>
   ```
3. If the contract is missing, scaffold in dry-run:
   ```bash
   $SETUP/cvv-scaffold.sh --project <project> --profile server-proxy
   ```
4. Re-run with `--apply` only after reviewing target files.
5. Edit placeholders in `docs/deployment.config.json` and `docs/ENV.md`.
6. Plan env vars for production and preview:
   ```bash
   $SETUP/cvv-env-plan.sh --project <project> --env production --target all
   $SETUP/cvv-env-plan.sh --project <project> --env preview --target all
   ```
7. Run the local prerequisite doctor, especially on a new machine:
   ```bash
   $SETUP/cvv-doctor.sh --project <project> --target all
   ```
8. Generate missing local secrets outside the LLM:
   ```bash
   $SETUP/cvv-secrets.sh --project <project> --env all --generate-missing --apply
   ```
9. Apply Vercel/Convex env only on explicit request:
   ```bash
   $SETUP/cvv-env-apply.sh --project <project> --env production --target all --secrets-file <project>/.deploy/secrets.env --apply
   $SETUP/cvv-env-apply.sh --project <project> --env preview --target all --secrets-file <project>/.deploy/secrets.env --apply
   ```
10. Run the audit again and address `FAIL` before deploy.

## Upgrade Flow

For existing projects, use the wizard upgrade action. It compares runtime files
with current central templates, shows diffs, and updates only after
confirmation. The wizard upgrade intentionally updates only
`scripts/cloud-env.sh`, `deploy-backend.sh`, and `deploy-backend-preview.sh`;
it does not overwrite `docs/deployment.config.json`, `docs/ENV.md`, or
`.env.example`. The central scripts are not copied into projects; only the thin
wrapper and project contract files are versioned locally.

## Secret Rotation

Prefer `CURRENT`/`PREVIOUS` env vars for rotatable secrets:

- `APP_PROXY_SECRET_CURRENT_<ENV>` and `APP_PROXY_SECRET_PREVIOUS_<ENV>`
- `CONVEX_AUTH_PRIVATE_KEY_B64_CURRENT` and
  `CONVEX_AUTH_PRIVATE_KEY_B64_PREVIOUS`
- `CONVEX_AUTH_KEY_ID_CURRENT` and `CONVEX_AUTH_KEY_ID_PREVIOUS`

Rotate locally first, then apply cloud env:

```bash
$SETUP/cvv-secrets.sh --project <project> --env preview --rotate app-proxy --apply
$SETUP/cvv-env-apply.sh --project <project> --env preview --target all --secrets-file <project>/.deploy/secrets.env --apply
```

Never print the generated values. Verification should list env var names only.

## References

- `/Users/dannywannagat/Code/coding-agent-setup/scripts/convex-vercel/AGENTS.md`:
  agent quickstart for the central scripts.
- `/Users/dannywannagat/Code/coding-agent-setup/scripts/convex-vercel/README.md`:
  operator workflow, command map, secret model, safety guarantees, and
  Preview/JWKS caveats.
- `references/patterns.md`: standard architecture and env-var matrix.
- `references/migration.md`: existing-project migration checklist.
- `references/prompts.md`: reusable prompts for project bootstrap, audit,
  hardening, and migration.

### Skill-Independent Docs

For non-Skill agent contexts (Codex, opencode), or when an agent needs an
unattended runbook rather than skill-style guidance:

- `/Users/dannywannagat/Code/coding-agent-setup/scripts/convex-vercel/docs/ROLLOUT.md`:
  phased runbook with three mandatory pause gates for conforming an existing
  project.
- `/Users/dannywannagat/Code/coding-agent-setup/scripts/convex-vercel/docs/PROFILES.md`:
  concrete profile catalog with stack signatures and per-project examples.
- `/Users/dannywannagat/Code/coding-agent-setup/scripts/convex-vercel/docs/PROJECT-BRIEF-TEMPLATE.md`:
  capture template for analyzing projects on the local Mac.
- `/Users/dannywannagat/Code/coding-agent-setup/scripts/convex-vercel/docs/BROWSER-TESTING.md`:
  Playwright + Vercel Protection Bypass for Automation.
- `/Users/dannywannagat/Code/coding-agent-setup/scripts/convex-vercel/docs/SECRETS-SYNC.md`:
  1Password CLI as canonical multi-machine secrets source.
- `/Users/dannywannagat/Code/coding-agent-setup/scripts/convex-vercel/docs/AGENT-PROMPTS.md`:
  copy-paste prompts for non-Skill contexts.
