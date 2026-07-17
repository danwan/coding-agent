---
name: security-review
description: >
  Pre-merge security checklists and audit commands. Required before merging PRs
  that touch auth, data access, or APIs. For Convex-specific deep review, use
  /convex-security-audit instead. Triggers: "security review",
  "pre-merge check", "review security".
allowed-tools: Read, Grep, Glob, Bash
version: 1.0.0
effort: high
---

# Security Review

> For Convex-specific deep review, use `/convex-security-audit`. This skill covers general application security.

Pre-merge checklists for PRs touching auth, data access, or APIs.

## Scope Detection

**Verify stack before applying stack-specific checks.** This skill's checklists assume server-side endpoints and (optionally) Convex. Per Golden Rule #8 and `~/.claude/skills/stack-detection/SKILL.md`: if the project has no server-side endpoints at all (e.g. static Next.js on Vercel with a third-party form handler, pure client-side SPA), mark the entire "Rate Limiting", "Session Management", "Backend-to-Backend Auth", and "Cron Jobs" sections as `N/A — no server-side endpoints` and do NOT flag them as CRITICAL/HIGH. "Missing rate limiting" on a project without server endpoints is a reviewer fabrication, not a finding.

Before running checklists, determine which sections apply:

```bash
# Detect the repo's default branch (works for main, master, develop, trunk, etc.).
# Falls back to "main" if origin/HEAD is not set; run `git remote set-head origin -a` once to fix.
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo main)
git diff "$DEFAULT_BRANCH"...HEAD --name-only
```

- **User-facing login/auth routes changed** (login, session creation, credential verification) → Session Management + Rate Limiting + Regression Checklist
- **Service-to-service/API key routes changed** (routes that validate a shared secret from another service) → Backend-to-Backend Auth + Regression Checklist
- **Convex functions changed** (requires `convex/` directory) → run Regression Checklist, then delegate to `/convex-security-audit` for deep review
- **Cron/scheduled jobs changed** (files under `api/cron/`, `api/scheduled/`, `api/jobs/`, or referencing `CRON_SECRET`) → run Cron Jobs section + Regression Checklist
- **Frontend-only changes** → run Regression Checklist only (skip backend sections)
- **No server-side endpoints at all** → skip all backend checklists; mark them `N/A`
- **Multiple areas** → run all applicable sections

Skip sections that don't apply to the PR's changed files. **Report skipped sections explicitly** ("N/A — no Convex", "N/A — no server endpoints") rather than silently omitting them.

## Regression Checklist

Before merging:

- [ ] Sensitive mutations use `internalMutation` (not public)
- [ ] Non-auth endpoints verify session/secret before any business logic (login/credential routes are exempt — they must parse the body to extract credentials)
- [ ] No `v.any()` without documented justification
- [ ] Secrets compared with timing-safe functions
- [ ] Error messages don't leak implementation details
- [ ] Rate limiting exists for endpoints that authenticate users via credentials (login, registration, password reset)
- [ ] Environment variables follow naming convention
- [ ] No hardcoded secrets or credentials
- [ ] New public queries justified with comment

## Audit Checklists

### Backend-to-Backend Auth
- [ ] HTTP endpoints validate secret BEFORE any logic
- [ ] Secret checked before parsing body or DB access
- [ ] 401 for mismatch, 500 for not_configured
- [ ] Secret in env vars, not code

### Session Management
- [ ] Tokens are 256-bit cryptographically random
- [ ] Cookies: HttpOnly, SameSite=Strict, Secure (prod)
- [ ] Session TTL appropriate (7 days typical)
- [ ] Session store is server-side (KV/Redis/DB)

### Browser Fingerprinting
- [ ] Fingerprint sent with EVERY authenticated request
- [ ] Middleware validates fingerprint matches stored value
- [ ] Mismatch triggers re-auth (not error)

### Rate Limiting
- [ ] Rate limiting is SERVER-SIDE (not just UI)
- [ ] Exponential backoff after failures
- [ ] Successful auth clears rate limit
- [ ] Rate limit data has TTL to auto-expire

### Cron Jobs
- [ ] Cron routes check Authorization header
- [ ] CRON_SECRET separate from other secrets
- [ ] Cron routes excluded from session middleware

## Quick Audit Commands

```bash
# Missing auth in API routes
grep -r "export async function" app/api/ | grep -v "checkSecret\|verifySession"

# Timing attack vulnerable comparisons
grep -r "=== process.env" --include="*.ts" | grep -v timingSafeEqual
```

## Common Vulnerability Patterns

| Wrong | Right |
|-------|-------|
| `if (cookie) allow` | `if (await verifySession(cookie)) allow` |
| `secret === input` | `crypto.timingSafeEqual()` |
| `const SECRET = "abc"` | `process.env.SECRET` |
| UI countdown only | Server-side rate limit |
| `document.cookie` accessible | `HttpOnly` flag set |

## Security Standards (Stack-Checkliste)

> Principles for Next.js + Convex + Python stack **when those technologies are in use**. Verify per-project per Golden Rule #8 before applying anything stack-specific. For detection signatures, see `~/.claude/skills/stack-detection/SKILL.md`.

### Authentication

- **Timing-safe comparison (CRITICAL):** Always `crypto.timingSafeEqual()` for secret comparison. Never `===`.
- **Session tokens:** 256-bit random (`randomBytes(32).toString("hex")`). Server-side store with TTL.
- **Cookies:** `HttpOnly; SameSite=Strict` always. `Secure` in production.
- **Defense in depth:** Auth check in middleware AND route handler. Never single auth layer.

### Rate Limiting

**Applies to:** Endpoints that (a) mutate persistent state, (b) hit paid or rate-limited third-party APIs on behalf of the user, or (c) expose authentication/credential verification. Static content, read-only edge routes, pure client-rendered pages, and projects with no server-side endpoints at all do **not** require server-side rate limiting. See `~/.claude/skills/stack-detection/SKILL.md` → "Server-side endpoints" for the detection signature.

**When applicable:** server-side rate limiting required, exponential backoff for auth failures, clear on success, per-IP with TTL.

**When NOT applicable** (e.g. static Next.js site on Vercel with a third-party form handler, pure client-side SPA without API routes): do not flag "missing rate limiting" as a finding. Mark the rule "N/A — no server-side endpoints" and move on.

### Error Handling

Production: generic "Internal server error" — never expose stack traces. Use `x-request-id` for correlation. Log full errors server-side only.

### Environment Variables

| Pattern | Purpose |
|---------|---------|
| `{APP}_PROXY_SECRET` | Server-to-server auth |
| `{APP}_CRON_SECRET` | Cron jobs |
| `{APP}_{FEATURE}_SECRET` | Feature-specific |
| `NEXT_PUBLIC_*` | Client-safe ONLY |

Never commit secret values or `.env*` files.

### Input Validation

Validate before processing: URL format/domains, strict regex, `parseInt()` with defaults. Sanitize: `input.slice(0, maxLen)`.
