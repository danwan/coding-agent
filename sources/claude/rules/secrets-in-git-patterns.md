---
paths:
  - "**/.env*"
  - "**/.gitignore"
  - "**/.env.example"
  - "**/secrets*"
  - "**/credentials*"
  - "**/*.pem"
  - "**/*.key"
---

# Secrets in Git — Pattern Catalog

> Preventive conventions (NEVER-list, redaction, allowlist) live in `~/.claude/rules/secrets-in-git.md`.
> Background, rotation runbook: `~/.claude/runbooks/secrets-in-git-runbook.md`

## Pattern Set

Each pattern below is a HARD signal to self-check for before publishing. Patterns are intentionally over-eager — treating a false positive as a secret is cheaper than a leak. Apply the False-Positive whitelist (next section) before deciding a match is real.

| Pattern | Regex | Examples |
|---|---|---|
| Hex ≥ 32 chars (context-aware) | `[a-f0-9]{32,}` after FP-whitelist | bcrypt salts, SHA-256, raw `randomBytes(16+).toString('hex')` |
| Base64-like ≥ 40 chars (mixed) | `[A-Za-z0-9+/_-]{40,}={0,2}` w/ digit + letter | API tokens, `randomBytes().toString('base64')` |
| JWT triplet | `eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+` | session, OAuth ID tokens |
| Sensitive var=value | `[A-Z][A-Z0-9_]*(SECRET\|TOKEN\|KEY\|PASSWORD\|PASSWD\|HASH\|PIN\|APIKEY\|API_KEY)=[^\s"']{8,}` | `APP_PROXY_SECRET=…`, `APP_PIN=…`, `CONVEX_DEPLOY_KEY=…`, `VERCEL_TOKEN=…`, `*_HASH=…` |
| Convex deploy key | `(prod\|dev):[a-z-]+-[0-9]+\|[A-Za-z0-9+/=_-]+` | `prod:example-deploy-000\|…` |
| GitHub PAT | `gh[pousr]_[A-Za-z0-9]{20,}` | `ghp_…`, `ghs_…` |
| AWS Access Key | `AKIA[0-9A-Z]{16}` | `AKIA…` |
| Stripe key | `(sk\|pk\|rk)_(live\|test)_[A-Za-z0-9]{20,}` | `sk_live_…` |
| OpenAI/Anthropic key | `sk-(ant-)?[A-Za-z0-9_-]{20,}` | `sk-ant-api03-…`, `sk-…` |
| Bcrypt/Argon2 hash | `\$2[aby]?\$[0-9]{2}\$[A-Za-z0-9./]{50,}` and `\$argon2(id\|i\|d)?\$` | password hashes |
| Private key block | `-----BEGIN [A-Z ]*PRIVATE KEY-----` literal | RSA/EC/OpenSSH/PGP |

## False-Positive Whitelist (apply before pattern match)

Treat these as non-matches — ignore them before checking the pattern set, so legitimate text is never mistaken for a secret:

- **Trailer lines:** `Co-authored-by:`, `Signed-off-by:`, `Reviewed-by:`, `Acked-by:`, `Tested-by:`, `Reported-by:` — entire line dropped.
- **Commit-SHA references:** `commit <sha>`, `revert <sha>`, `cherry-pick <sha>`, `merge <sha>`, `see <sha>`, `parent <sha>`, `tree <sha>` — token replaced with placeholder.
- **Commit-range refs:** `abc1234..def5678` — replaced with placeholder.
- **Explicit redaction placeholders:** `<REDACTED:...>`, `<set via vercel env add ...>`, `<set via convex env set ...>`, `<set via chat session>`, `<rotated secret — see chat session>`, `<chat session>` — stripped before scan.

## False-Positive Judgment Call

If a value matches a pattern but is genuinely not a secret (e.g. a commit SHA, a test fixture), say so explicitly and proceed — there is no scanner to override, just your own judgment. When in doubt, ask the user.

## Out of scope (intentional)

- Working-tree gitleaks scan (full-repo content) and normal local shell exploration — that's gitleaks/CodeRabbit territory.
- Web-UI bodies typed directly by the user in the browser.
- MCP servers that call GitHub's HTTP API directly (no Bash shell). Sub-Agent Discipline #8 in `~/.claude/CLAUDE.md` is the cognitive-layer backstop for that path.
