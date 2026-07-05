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

**Verify stack before applying stack-specific checks.** This skill's checklists assume server-side endpoints and (optionally) Convex. Per Golden Rule #8 and `~/.claude/rules/stack-detection.md`: if the project has no server-side endpoints at all (e.g. static Next.js on Vercel with a third-party form handler, pure client-side SPA), mark the entire "Rate Limiting", "Session Management", "Backend-to-Backend Auth", and "Cron Jobs" sections as `N/A — no server-side endpoints` and do NOT flag them as CRITICAL/HIGH. "Missing rate limiting" on a project without server endpoints is a reviewer fabrication, not a finding.

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
