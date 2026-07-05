---
name: pin-auth
description: Add PIN-based authentication to Next.js web apps. Two variants - Convex (full security with DB sessions, browser fingerprinting, persistent rate limiting) and Lightweight (HMAC cookies, in-memory rate limiting, no DB). Use when - "add PIN auth", "protect with PIN", "PIN authentication", "simple auth for internal tool", "PIN vor die Webseite".
disable-model-invocation: true
allowed-tools: Bash, Read, Grep, Glob, Write, Edit, AskUserQuestion, Agent, mcp__context7__resolve-library-id, mcp__context7__query-docs
version: 2.0.0
---

# PIN Authentication for Next.js

Adds PIN-based authentication to any Next.js (App Router) web app. Security: timing-safe comparison, HttpOnly cookies, exponential rate limiting, fail-closed design.

**Two variants:**
- **Convex**: DB sessions, browser fingerprinting (ThumbmarkJS), persistent rate limiting, defense-in-depth
- **Lightweight**: HMAC-signed cookie sessions, in-memory rate limiting, no DB needed

## Variables

| Variable | Example | Derived from |
|----------|---------|-------------|
| `PREFIX` | `myapp` | User answer or package.json name |
| `PREFIX_UPPER` | `MYAPP` | PREFIX uppercased |
| `PIN_LENGTH` | `4` | User answer (default 4) |
| `SESSION_TTL_MS` | `604800000` | User answer (default 7 days) |
| `LANG` | `de` | User answer (default de) |
| `APP_DIR` | `app/` or `src/app/` | Project structure |
| `LIB_DIR` | `lib/` or `src/lib/` | Project structure |
| `COMPONENTS_DIR` | `components/` or `src/components/` | Project structure |
| `IMPORT_PREFIX` | `@/lib` or `@/src/lib` | Based on tsconfig paths |

**UI text:** de: title="PIN eingeben", error="Falscher PIN", aria="PIN Ziffer" / en: title="Enter PIN", error="Wrong PIN", aria="PIN digit"

---

## Phase 1: Discovery

Read these in parallel to understand the project:

1. `package.json` — project name (PREFIX default), check for `next`, `convex`, `@thumbmarkjs/thumbmarkjs`, `clsx`, `tailwind-merge`
2. `middleware.ts` or `src/middleware.ts` — exists? (needs merge)
3. `convex/schema.ts` — exists? (needs merge)
4. `convex/http.ts` — exists? (needs merge)
5. Root layout: `app/layout.tsx` or `src/app/layout.tsx`
6. Grep for `export function cn` — find existing cn() utility path

Record: `HAS_CONVEX`, `HAS_MIDDLEWARE`, `HAS_SCHEMA`, `HAS_HTTP`, `LAYOUT_PATH`, `CN_PATH`, `SRC_PREFIX` (empty or `src/`).

---

## Phase 2: Configuration

Ask the user with AskUserQuestion:

**Question 1 — Variant** (if HAS_CONVEX, recommend Convex):
- "Convex (Full Security)" — DB sessions, fingerprinting, persistent rate limiting
- "Lightweight (No DB)" — HMAC cookies, in-memory rate limiting

**Question 2 — App Prefix**: default from package.json name.

**Question 3 — PIN Length**: default 4 (range 4-8).

**Question 4 — UI Language**: Deutsch (default) or English.

Optional: Session TTL (default 7 days).

---

## Phase 3: Lookup Current API Patterns (MANDATORY)

**Before generating ANY code**, look up current API patterns via Context7. Do NOT rely on training data for framework-specific syntax.

### 3.1 Resolve Library IDs

Use `mcp__context7__resolve-library-id` for:
- "Next.js" (expect something like `/vercel/next.js`)
- "Convex" (only if Convex variant)
- "ThumbmarkJS" (only if Convex variant)

### 3.2 Query Current Patterns (run in parallel where possible)

| Query | Library | What you need |
|-------|---------|--------------|
| "App Router route handler POST NextRequest NextResponse JSON" | Next.js | Route handler file structure and exports |
| "middleware NextRequest NextResponse matcher config" | Next.js | Middleware definition pattern |
| "defineTable defineSchema index validator v.string" | Convex | Schema definition syntax |
| "internalMutation internalQuery args returns handler" | Convex | Internal function definition |
| "httpAction httpRouter http.route POST method path" | Convex | HTTP endpoint registration |
| "getFingerprint import" | ThumbmarkJS | Import path and API |

Store these patterns. Use them as the basis for all generated code in Phase 5.

**If a lookup fails**, fall back to training data but note the uncertainty.

**If lookups conflict with the project's existing code patterns** (e.g., the project uses an older API version), match the project's existing patterns.

---

## Phase 4: Dependencies

```bash
# Convex variant only:
npm install @thumbmarkjs/thumbmarkjs

# If cn() utility not found AND clsx/tailwind-merge not installed:
npm install clsx tailwind-merge
```

If `cn()` not found, generate `{LIB_DIR}/utils.ts`:

```typescript
import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";
export function cn(...inputs: ClassValue[]) { return twMerge(clsx(inputs)); }
```

---

## Phase 5: Code Generation

### SECURITY INVARIANTS — Read `references/security-invariants.md` FIRST. Every file must satisfy those constraints. Security-critical code is marked COPY EXACTLY in that file — use it verbatim.

Generate files in dependency order. Use current API patterns from Phase 3 lookups for framework-specific code.

---

### 5.1 PinInput Component (shared, both variants)

**File:** `{COMPONENTS_DIR}/PinInput.tsx`

Read `references/PinInput.template.tsx` and copy it. Substitute these variables:
- `{{PIN_LENGTH}}` → actual PIN length
- `{{IMPORT_PREFIX}}` → actual import prefix
- `{{LANG_TITLE}}` → localized title
- `{{LANG_ARIA}}` → localized aria label
- `{{LANG_ERROR}}` → localized error message

This is custom UI logic with no framework dependencies beyond React basics — do not modify the component logic.

---

### 5.2 Fingerprint Client (Convex variant ONLY)

**File:** `{LIB_DIR}/client/fingerprint.ts`

**Exports:**
- `getFingerprint(): Promise<string>` — returns cached fingerprint or generates via ThumbmarkJS
- `clearFingerprintCache(): void` — clears localStorage + memory cache
- `authFetch(input: RequestInfo | URL, init?: RequestInit): Promise<Response>` — fetch wrapper that adds `x-fingerprint` header

**Behavior:**
- Cache fingerprint in memory + `localStorage` under key `{PREFIX}_fp`
- If ThumbmarkJS fails, generate fallback: `fallback-${crypto.randomUUID()}`
- `authFetch`: on 401 with `"Session expired"` or `"Unauthorized"`, clear cache and `window.location.reload()`
- Use ThumbmarkJS API from Phase 3 lookup

---

### 5.3 Server: pinAuth.ts

**File:** `{LIB_DIR}/server/pinAuth.ts`

**Exports (both variants):**
- `isPinConfigured(): boolean` — checks `{PREFIX_UPPER}_PIN` env var
- `verifyPin(pin: string): boolean` — **COPY EXACTLY from security-invariants.md Section 1.1**
- `createSessionCookie(token: string): string` — **COPY EXACTLY from security-invariants.md Section 2**
- `clearSessionCookie(): string` — **COPY EXACTLY from security-invariants.md Section 2**
- `getSessionFromCookie(cookieHeader: string | null): string | null` — parse cookie header
- `COOKIE_NAME` constant: `{PREFIX}_session`

**Additional exports — Convex variant:**
- `createSession(ip: string, fingerprint: string): Promise<string>` — generates `randomBytes(32).toString('hex')` token, calls HTTP action `/api/auth/create-session`
- `verifySession(token: string, fingerprint: string): Promise<boolean>` — calls HTTP action `/api/auth/verify-session`, returns false on any error (fail-closed)
- `deleteSession(token: string): Promise<void>` — calls HTTP action `/api/auth/delete-session`

Convex variant needs: `callHttpAction(path, args)` helper that POSTs to `{CONVEX_HTTP_URL}{path}` with `x-{PREFIX}-secret` header. `getConvexHttpUrl()` reads `CONVEX_HTTP_URL` env, fallback: transform `NEXT_PUBLIC_CONVEX_URL` (.convex.cloud → .convex.site).

**Additional exports — Lightweight variant:**
- `createSessionToken(): string` — **COPY EXACTLY from security-invariants.md Section 1.3**
- `verifySessionToken(token: string): boolean` — **COPY EXACTLY from security-invariants.md Section 1.3**

---

### 5.4 Server: pinRateLimit.ts

**File:** `{LIB_DIR}/server/pinRateLimit.ts`

**Exports (both variants, same interface):**
- `checkPinRateLimit(ip: string): Promise<{ allowed: true } | { allowed: false; retryAfterSeconds: number }>`
- `recordFailedAttempt(ip: string): Promise<number>` — returns timeout seconds
- `clearRateLimit(ip: string): Promise<void>`

**Rate limit formula:** `calcTimeout` — **COPY EXACTLY from security-invariants.md Section 3**

**Convex variant:** Delegates to HTTP actions `/api/auth/check-rate-limit`, `/api/auth/record-failed-attempt`, `/api/auth/clear-rate-limit` via `callHttpAction`.

**Lightweight variant:** In-memory `Map<string, { attempts, lockedUntil }>` with periodic cleanup (every 10 min, clear entries older than `MAX_TIMEOUT * 2` seconds). Use `.unref?.()` on the cleanup interval.

---

### 5.5 Auth Helper (Convex variant ONLY)

**File:** `{LIB_DIR}/server/authHelper.ts`

**Exports:**
- `verifyRequestAuth(request: Request): Promise<{ ok: boolean; error?: string }>`

**Behavior:** If PIN not configured → `{ ok: true }`. Otherwise: extract session token from cookie, extract fingerprint from `x-fingerprint` header, verify both via `verifySession`. Missing token/fingerprint → `{ ok: false }`.

---

### 5.6 PinGuard Component

**File:** `{COMPONENTS_DIR}/PinGuard.tsx`
**Directive:** `"use client"`

**Props:** `{ children: React.ReactNode }`

**State machine:**
- `loading` → on mount, call GET `/api/auth/status` (Convex: use `authFetch`)
  - `{ authenticated: true }` → `authenticated`
  - `{ pinRequired: true }` → `pin_required`
  - Network error → `pin_required` (fail-closed)
- `pin_required` → render `<PinInput onComplete={handlePinSubmit} countdown={countdown} error={error && countdown === 0} />`
  - On submit: POST `/api/auth/verify-pin` with `{ pin }` (Convex: add `x-fingerprint` header via `getFingerprint()`)
  - `{ success: true }` → `authenticated`
  - `{ retryAfterSeconds: N }` → start countdown (N→0, interval 1s)
  - Status 500 or parse error → show error, no countdown
- `authenticated` → render `{children}`

**Loading state:** centered spinner (Tailwind: `w-8 h-8 border-2 border-amber-500 border-t-transparent rounded-full animate-spin`)

---

### 5.7 API Route: verify-pin

**File:** `{APP_DIR}/api/auth/verify-pin/route.ts`

Use current Next.js route handler patterns from Phase 3 lookup.

**Export:** `POST(request: NextRequest)`

**Flow:**
1. Check `isPinConfigured()` → 500 if not
2. Extract IP: `x-forwarded-for` (first entry) → `x-real-ip` → `"127.0.0.1"`
3. Check rate limit → 429 if blocked
4. Parse body, validate PIN format: `/^\d{PIN_LENGTH}$/` → 400 if invalid
5. Verify PIN → 401 + `recordFailedAttempt` if wrong
6. Clear rate limit on success
7. Convex: require `x-fingerprint` header (not "unknown") → 400 if missing. Create session with IP + fingerprint
8. Lightweight: create session token
9. Return `{ success: true }` with `Set-Cookie` header

**Status codes:** Follow security-invariants.md Section 4 EXACTLY.

---

### 5.8 API Route: status

**File:** `{APP_DIR}/api/auth/status/route.ts`

**Export:** `GET(request: NextRequest)`

**Flow:**
1. If PIN not configured → `{ authenticated: true, pinRequired: false }`
2. Extract session token from cookie
3. Convex: also extract fingerprint from `x-fingerprint` header. Verify both.
4. Lightweight: verify session token.
5. Return `{ authenticated: bool, pinRequired: !bool }`

---

### 5.9 Middleware

**File:** `middleware.ts` (or `src/middleware.ts`)

Use current Next.js middleware patterns from Phase 3 lookup.

**Logic:**
1. If `{PREFIX_UPPER}_PIN` not set → `NextResponse.next()`
2. If path not `/api/` → `NextResponse.next()` (only protect API routes)
3. Extract session token from cookie
4. Convex: also extract fingerprint. Verify session via `verifySession`. Missing/invalid → 401 JSON
5. Lightweight: verify session token. Invalid → 401 JSON
6. Valid → `NextResponse.next()`

**Matcher:** Exclude `_next/`, `_vercel/`, `favicon.ico`, `robots.txt`, `api/auth/` (auth routes must be accessible without session)

**MERGE STRATEGY (if middleware already exists):**
1. Read existing middleware
2. Add PIN auth imports at top
3. Add PIN auth check at START of middleware function, before existing logic
4. Merge matcher patterns: union of existing exclusions + `api/auth/`
5. Keep existing middleware logic intact

---

### 5.10 Convex Backend (Convex variant ONLY)

Use current Convex API patterns from Phase 3 lookup for all definitions.

#### convex/pinSessions.ts

**ALL functions MUST be `internal`** (internalMutation, internalQuery).

**Functions:**
- `internalCreate({ token, ip, fingerprint })` → insert with `createdAt: Date.now()`, `expiresAt: Date.now() + SESSION_TTL_MS`
- `internalDeleteSession({ token })` → find by token index, delete
- `internalCleanupExpired({})` → delete where `expiresAt < Date.now()`
- `internalVerify({ token, fingerprint })` → find by token index, check expiry + fingerprint match, reject `"unknown"`. Return session data or null.

#### convex/pinRateLimits.ts

**ALL functions MUST be `internal`.**

**Functions:**
- `internalRecordFailedAttempt({ ip })` → increment attempts, set `lockedUntil` using `calcTimeout` formula from security-invariants.md
- `internalClear({ ip })` → delete by ip index
- `internalCleanupExpired({})` → delete where `expiresAt < Date.now()`
- `internalCheck({ ip })` → check if `lockedUntil > Date.now()`, return `{ allowed }` or `{ allowed: false, retryAfterSeconds }`

#### convex/schema.ts — Tables to MERGE

```
pinSessions: defineTable({
  token, ip, fingerprint, createdAt, expiresAt — all appropriate types
}).index("by_token", ["token"]).index("by_expiresAt", ["expiresAt"])

pinRateLimits: defineTable({
  ip, attempts, lockedUntil (optional), expiresAt — all appropriate types
}).index("by_ip", ["ip"]).index("by_expiresAt", ["expiresAt"])
```

Use exact Convex validator syntax from Phase 3 lookup.

#### convex/http.ts — Routes to ADD

Add 6 auth routes (all POST):
- `/api/auth/create-session`
- `/api/auth/delete-session`
- `/api/auth/verify-session`
- `/api/auth/record-failed-attempt`
- `/api/auth/clear-rate-limit`
- `/api/auth/check-rate-limit`

Each route: check proxy secret via `pinAuthGuard` first (**COPY EXACTLY from security-invariants.md Section 5**), parse JSON body, call appropriate internal function, return JSON response.

**IMPORTANT:** `timingSafeCompare` and `checkPinAuthSecret` — **COPY EXACTLY from security-invariants.md Section 1.2** (Convex runtime has no `crypto` module).

Ensure `internal` is imported from `"./_generated/api"` and `httpAction` from `"./_generated/server"`.

---

## Phase 6: Integration

### 6.1 Wrap layout.tsx with PinGuard

Read existing layout, add import and wrap `{children}`:

```tsx
import { PinGuard } from "{IMPORT_PREFIX_COMPONENTS}/PinGuard";
// Wrap {children} — innermost wrapper (inside any providers):
<PinGuard>{children}</PinGuard>
```

### 6.2 Deploy Convex (Convex variant only)

```bash
npx convex dev    # local development
npx convex deploy # production
```

---

## Phase 7: Environment Variables

### Convex variant

| Variable | Where | Value |
|----------|-------|-------|
| `{PREFIX_UPPER}_PIN` | `.env.local` + Vercel | Your PIN (e.g. `1234`) |
| `{PREFIX_UPPER}_PROXY_SECRET` | `.env.local` + Vercel + Convex | `openssl rand -hex 32` |
| `NEXT_PUBLIC_CONVEX_URL` | `.env.local` + Vercel | Already set if Convex configured |

### Lightweight variant

| Variable | Where | Value |
|----------|-------|-------|
| `{PREFIX_UPPER}_PIN` | `.env.local` + Vercel | Your PIN (e.g. `1234`) |
| `{PREFIX_UPPER}_SESSION_SECRET` | `.env.local` + Vercel | `openssl rand -hex 32` |

When PIN env var is not set, auth is disabled (useful for local dev without PIN).

---

## Phase 8: Verification

1. Start dev server: `npm run dev`
2. Open browser — should see PIN input screen
3. Enter correct PIN — should transition to app content
4. Reload — session persists (cookie)
5. Incognito window — shows PIN input (no session)
6. Enter wrong PIN 3x — see countdown (5s, 10s, 20s)
7. DevTools > Application > Cookies — verify `HttpOnly`, `SameSite=Strict`
8. **Read `references/security-invariants.md` Section 7** — run through the entire post-generation checklist
9. Report results to user
