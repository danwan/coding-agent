# Reusable Prompts

## New Project Bootstrap

Audit this repo and set up the standard Vercel + Convex deployment contract.
Use `/Users/dannywannagat/Code/coding-agent-setup/scripts/convex-vercel`.
Start with `cvv-audit.sh --project .`, then scaffold dry-run. Use the
`server-proxy` profile unless the repo clearly needs direct Convex realtime
browser access. Do not write cloud env vars unless I explicitly approve
`cvv-env-apply.sh --apply`.

## Existing Project Migration

Migrate this existing project to the standard Vercel + Convex deployment
framework. First inventory current Vercel root, Convex prod/dev deployments,
deploy scripts, Vercel env names, Convex env names, Modal apps, and public
Convex functions. Then create/update `docs/deployment.config.json`,
`docs/ENV.md`, `.env.example`, and hardened deploy scripts. Keep secrets out of
git and out of the chat. Finish with `cvv-audit.sh --strict`.

## Security Hardening

Review this project's API security for the selected profile. Prove whether
unauthenticated direct calls to Next.js API routes, Convex public functions,
Convex HTTP actions, and Modal endpoints can do expensive work or read/write
protected data. Fix only after identifying file/line evidence and a minimal
test or reproduction path.

## Env Apply

Use `cvv-env-plan.sh` for production and preview first. Show me the masked plan
and identify which values are public URLs versus secrets. Do not run
`cvv-env-apply.sh --apply` until I approve the exact target and environment.

## Post-Migration Review

Run the standard audit and summarize only remaining `FAIL` and high-risk
`WARN` items. Confirm whether Vercel has only runtime variables, local `.env`
has deploy keys, Convex env has backend/runtime variables, and Modal secrets
are project-scoped.
