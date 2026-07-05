# Standard Patterns

## Environment Mapping

| Git branch | Vercel environment | Convex deployment | Modal app |
| --- | --- | --- | --- |
| `main` | `production` | production Convex deployment | production Modal app |
| non-`main` | `preview` | shared development Convex deployment | preview/development Modal app |

Vercel auto-deploys frontend on push. Convex and Modal do not; use hardened
project scripts.

## Vercel Variables

Allowed in Vercel:

- `NEXT_PUBLIC_CONVEX_URL`
- `NEXT_PUBLIC_CONVEX_SITE_URL`
- public app URLs
- server-side runtime secrets used by Next.js API routes, for example
  `APP_PROXY_SECRET_CURRENT`, `CRON_SECRET`, or app-specific PIN/session secrets
- JWT signing private keys for direct Convex auth, for example
  `CONVEX_AUTH_PRIVATE_KEY_B64_CURRENT`

Forbidden in Vercel:

- `CONVEX_DEPLOY_KEY`
- `CONVEX_DEPLOYMENT_PROD`
- `CONVEX_DEPLOYMENT_DEV`
- `MODAL_TOKEN`

`NEXT_PUBLIC_*` values are browser-exposed. Never put secrets in them.

## Convex Variables

Convex receives variables used by Convex functions at runtime:

- `APP_BASE_URL` for canonical app URL callbacks/links
- shared server-proxy secrets, for example `APP_PROXY_SECRET_CURRENT`
- third-party API secrets used by Convex actions
- JWT validation metadata, for example `CONVEX_AUTH_ISSUER`,
  `CONVEX_AUTH_JWKS_URL`, and `CONVEX_AUTH_AUDIENCE`

Avoid `NEXT_PUBLIC_*` names in Convex unless backend code truly reads the same
public value. Prefer server-only names such as `APP_BASE_URL`.

For direct Convex custom JWT auth, Convex must be able to fetch
`CONVEX_AUTH_JWKS_URL` at runtime. If Preview uses Vercel Deployment Protection,
the public preview URL may return Vercel login instead of JWKS. Either use a
production JWKS URL that is already deployed and public, or set Convex Preview
to a protected preview JWKS URL with Vercel Protection Bypass for Automation.
That bypass value is a secret-like operational token: store it only in Convex
env, never in Git or docs.

## Security Profiles

`direct-convex`:

- Browser can call public Convex functions.
- All public functions must validate auth/session and row access.
- Never rely on Next.js middleware/PIN to protect direct Convex calls.

`server-proxy`:

- Browser calls Next.js API routes.
- Next.js validates PIN/session/rate limits.
- Next.js calls Convex HTTP actions with a server-only secret.
- Core Convex DB functions are internal where possible.

`modal-proxy`:

- Same as server-proxy.
- Modal endpoint calls are authenticated with a server-only secret.
- Modal app names and secret names are project-scoped.

## Deploy Scripts

Run the doctor first on new machines:

```bash
./scripts/cloud-env.sh doctor --target all
```

Production script:

- reads `CONVEX_DEPLOYMENT_PROD` from local `.env` or `.deploy/secrets.env`
- refuses non-`main`
- refuses dirty/untracked worktree
- verifies `HEAD == origin/main`
- checks key prefix `prod:<expected-deployment>|`
- runs lint/tests
- runs `npx convex deploy --yes`
- lists Convex env var names after deploy

Preview script:

- reads `CONVEX_DEPLOYMENT_DEV` from local `.env` or `.deploy/secrets.env`
- refuses `main`
- checks key prefix `dev:<expected-deployment>|`
- deploys to the shared development Convex deployment

## Local Secret Files

Generated runtime secrets live in `.deploy/secrets.env` with mode 600. The file
must be gitignored; setup scripts fail closed if a project-local secrets file is
not ignored by Git. Standard generated keys:

- `APP_PIN_PRODUCTION`, `APP_PIN_PREVIEW`
- `APP_PROXY_SECRET_CURRENT_PRODUCTION`, `APP_PROXY_SECRET_CURRENT_PREVIEW`
- optional `APP_PROXY_SECRET_PREVIOUS_PRODUCTION`,
  `APP_PROXY_SECRET_PREVIOUS_PREVIEW`
- `CONVEX_AUTH_PRIVATE_KEY_B64_CURRENT`
- optional `CONVEX_AUTH_PRIVATE_KEY_B64_PREVIOUS`
- `CONVEX_AUTH_KEY_ID_CURRENT`
- optional `CONVEX_AUTH_KEY_ID_PREVIOUS`

Agents should use scripts to generate/apply these values and should verify only
key names, never values.

## Modal

Modal deploys must use project-scoped app names, for example
`lanalyzer-prod` and `lanalyzer-preview`. Modal secrets should also be
project-scoped and documented in `docs/deployment.config.json` or `docs/ENV.md`.
