# Security Standards

> Principles for Next.js + Convex + Python stack **when those technologies are in use**. Verify per-project per Golden Rule #8 (`~/.claude/CLAUDE.md`) before applying anything stack-specific. For tool routing, invoke the `review-routing` skill. For detection signatures, see `~/.claude/rules/stack-detection.md`.

## Authentication

- **Timing-safe comparison (CRITICAL):** Always `crypto.timingSafeEqual()` for secret comparison. Never `===`.
- **Session tokens:** 256-bit random (`randomBytes(32).toString("hex")`). Server-side store with TTL.
- **Cookies:** `HttpOnly; SameSite=Strict` always. `Secure` in production.
- **Defense in depth:** Auth check in middleware AND route handler. Never single auth layer.

## Rate Limiting

**Applies to:** Endpoints that (a) mutate persistent state, (b) hit paid or rate-limited third-party APIs on behalf of the user, or (c) expose authentication/credential verification. Static content, read-only edge routes, pure client-rendered pages, and projects with no server-side endpoints at all do **not** require server-side rate limiting. See `~/.claude/rules/stack-detection.md` → "Server-side endpoints" for the detection signature.

**When applicable:** server-side rate limiting required, exponential backoff for auth failures, clear on success, per-IP with TTL.

**When NOT applicable** (e.g. static Next.js site on Vercel with a third-party form handler, pure client-side SPA without API routes): do not flag "missing rate limiting" as a finding. Mark the rule "N/A — no server-side endpoints" and move on.

## Error Handling

Production: generic "Internal server error" — never expose stack traces. Use `x-request-id` for correlation. Log full errors server-side only.

## Environment Variables

| Pattern | Purpose |
|---------|---------|
| `{APP}_PROXY_SECRET` | Server-to-server auth |
| `{APP}_CRON_SECRET` | Cron jobs |
| `{APP}_{FEATURE}_SECRET` | Feature-specific |
| `NEXT_PUBLIC_*` | Client-safe ONLY |

Never commit secret values or `.env*` files.

## Input Validation

Validate before processing: URL format/domains, strict regex, `parseInt()` with defaults. Sanitize: `input.slice(0, maxLen)`.
