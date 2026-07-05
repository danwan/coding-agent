# PIN Auth Security Invariants

Security-critical code patterns and verification checklist. Every generated file MUST satisfy these constraints.

---

## Section 1: Cryptographic Patterns (COPY EXACTLY)

### 1.1 Node.js timing-safe PIN comparison

Used in `pinAuth.ts` — NEVER use `===` for PIN/secret comparison:

```typescript
import { timingSafeEqual } from "crypto";

export function verifyPin(pin: string): boolean {
  const expectedPin = process.env.{{PREFIX_UPPER}}_PIN;
  if (!expectedPin) return true; // PIN not configured = auth disabled
  const pinBuffer = Buffer.from(pin.padEnd(32, "\0"));
  const expectedBuffer = Buffer.from(expectedPin.padEnd(32, "\0"));
  try { return timingSafeEqual(pinBuffer, expectedBuffer); }
  catch { return false; }
}
```

### 1.2 Convex runtime timing-safe comparison (XOR loop)

Used in `convex/http.ts` — Convex edge runtime has no `crypto` module:

```typescript
function timingSafeCompare(provided: string, expected: string): boolean {
  const maxLen = Math.max(provided.length, expected.length, 32);
  const a = provided.padEnd(maxLen, "\0");
  const b = expected.padEnd(maxLen, "\0");
  let result = 0;
  for (let i = 0; i < maxLen; i++) result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return result === 0;
}

function checkPinAuthSecret(request: Request): boolean {
  const expected = process.env.{{PREFIX_UPPER}}_PROXY_SECRET || "";
  if (!expected) return false;
  const secret = request.headers.get("x-{{PREFIX}}-secret") || "";
  return timingSafeCompare(secret, expected);
}
```

### 1.3 HMAC session token (Lightweight variant)

Used in `pinAuth.ts` for the Lightweight variant:

```typescript
import { randomBytes, timingSafeEqual, createHmac } from "crypto";

export function createSessionToken(): string {
  const secret = getSessionSecret();
  const payload = `${Date.now()}:${randomBytes(16).toString("hex")}`;
  const hmac = createHmac("sha256", secret).update(payload).digest("hex");
  return `${Buffer.from(payload).toString("base64url")}.${hmac}`;
}

export function verifySessionToken(token: string): boolean {
  if (!token) return false;
  const secret = getSessionSecret();
  const dotIndex = token.indexOf(".");
  if (dotIndex === -1) return false;
  const payloadB64 = token.slice(0, dotIndex);
  const providedHmac = token.slice(dotIndex + 1);

  let payload: string;
  try { payload = Buffer.from(payloadB64, "base64url").toString(); }
  catch { return false; }

  const expectedHmac = createHmac("sha256", secret).update(payload).digest("hex");
  const hmacBuf = Buffer.from(providedHmac.padEnd(64, "\0"));
  const expectedBuf = Buffer.from(expectedHmac.padEnd(64, "\0"));
  let hmacValid: boolean;
  try { hmacValid = timingSafeEqual(hmacBuf, expectedBuf); }
  catch { return false; }
  if (!hmacValid) return false;

  const timestamp = parseInt(payload.split(":")[0], 10);
  if (isNaN(timestamp)) return false;
  return Date.now() - timestamp < SESSION_TTL_MS;
}
```

### 1.4 Session token generation

Session tokens MUST be cryptographically random:

```typescript
import { randomBytes } from "crypto";
const token = randomBytes(32).toString("hex"); // 64-char hex string
```

---

## Section 2: Cookie Security Rules (COPY EXACTLY)

Every cookie operation MUST include these flags:

```typescript
// Creating a session cookie
export function createSessionCookie(token: string): string {
  const secure = process.env.NODE_ENV === "production" ? "; Secure" : "";
  return `${COOKIE_NAME}=${token}; Path=/; HttpOnly; SameSite=Strict${secure}`;
}

// Clearing a session cookie
export function clearSessionCookie(): string {
  return `${COOKIE_NAME}=; Path=/; HttpOnly; SameSite=Strict; Max-Age=0`;
}
```

Rules:
- `HttpOnly` — JavaScript cannot read the cookie
- `SameSite=Strict` — no cross-site requests
- `Secure` — ONLY in production (`process.env.NODE_ENV === "production"`)
- `Path=/` — always set
- No `Max-Age` on session cookies (cleared on browser close) — only on clear cookie

---

## Section 3: Rate Limiting Formula (COPY EXACTLY)

```typescript
const BASE_TIMEOUT = 5;
const MAX_TIMEOUT = 300;

function calcTimeout(n: number): number {
  return n <= 0 ? 0 : Math.min(BASE_TIMEOUT * Math.pow(2, n - 1), MAX_TIMEOUT);
}
// Sequence: 5s, 10s, 20s, 40s, 80s, 160s, 300s (capped)
```

Rules:
- Per-IP tracking (never per-user or per-session)
- Never expose raw attempt count in API responses
- Only return `allowed/denied` + `retryAfterSeconds`
- Clear rate limit on successful authentication

---

## Section 4: HTTP Response Rules

### Status code mapping (MANDATORY):

| Situation | Status | Response body |
|-----------|--------|--------------|
| PIN correct, session created | `200` | `{ success: true }` |
| PIN not configured | `500` | `{ error: "PIN not configured", serverError: true }` |
| Invalid PIN format | `400` | `{ error: "Invalid PIN format" }` |
| Invalid request body | `400` | `{ error: "Invalid request body" }` |
| Wrong PIN | `401` | `{ error: "Invalid PIN", retryAfterSeconds: N }` |
| Rate limited | `429` | `{ error: "Too many attempts", retryAfterSeconds: N }` |
| Missing fingerprint (Convex) | `400` | `{ error: "Missing fingerprint" }` |
| Server error (production) | `500` | `{ error: "Internal server error", serverError: true }` |
| Server error (development) | `500` | `{ error: "<truncated message>", serverError: true }` |
| Unauthorized (middleware) | `401` | `{ error: "Unauthorized" }` |
| Session expired (middleware) | `401` | `{ error: "Session expired" }` |

Rules:
- **Fail-closed:** All `catch` blocks return denial/error, never success
- **Production errors:** Generic "Internal server error" — never expose stack traces
- **Error message truncation:** `error.message.slice(0, 200)` in development
- **Never 200 for errors:** Auth failures are always 4xx

---

## Section 5: Convex Security Boundaries

Rules:
- ALL Convex functions are `internal` (`internalMutation`, `internalQuery`) — never public
- HTTP actions check proxy secret BEFORE any other logic
- Proxy secret header name: `x-{PREFIX}-secret`
- `{PREFIX_UPPER}_PROXY_SECRET` env var required — throw if missing
- Auth guard pattern: check secret first, return 401 if invalid, then proceed

```typescript
function pinAuthGuard(request: Request): Response | null {
  if (!checkPinAuthSecret(request)) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }
  return null;
}
```

---

## Section 6: Architecture Rules

- Defense in depth: middleware AND route handler both verify auth (Convex variant)
- PIN env var not set → auth disabled (for local dev), not error
- "unknown" fingerprint rejected at creation AND verification (Convex variant)
- Missing token → 401 (not 200 with error)
- Missing fingerprint → 401 (Convex variant)
- Expired session → 401
- Network/auth errors treated as invalid (fail-closed)

---

## Section 7: Post-Generation Checklist

Verify after ALL code is generated:

### Cryptographic
- [ ] PIN comparison uses `crypto.timingSafeEqual()` with 32-byte padded buffers — never `===`
- [ ] Convex HTTP action secret comparison uses XOR-based loop (no `crypto` in Convex runtime)
- [ ] HMAC tokens (lightweight) use `crypto.createHmac('sha256', secret)` with timing-safe verification
- [ ] Session tokens are `crypto.randomBytes(32).toString('hex')` — 64-char hex

### Cookies
- [ ] `HttpOnly` flag set (JavaScript cannot read)
- [ ] `SameSite=Strict` flag set (no cross-site requests)
- [ ] `Secure` flag set in production only (`process.env.NODE_ENV === "production"`)
- [ ] `Path=/` set

### Rate Limiting
- [ ] Exponential backoff formula: `min(5 * 2^(attempts-1), 300)` seconds
- [ ] Per-IP tracking
- [ ] No raw attempt count exposed in API responses

### Session Validation
- [ ] Convex variant: token AND fingerprint must match
- [ ] "unknown" fingerprint rejected at creation AND verification
- [ ] Missing token → 401 (not 200 with error)
- [ ] Expired session → 401
- [ ] Network/auth errors treated as invalid (fail-closed)

### Architecture
- [ ] All Convex functions are `internal` (internalMutation, internalQuery)
- [ ] Convex HTTP actions authenticated via proxy secret header
- [ ] Defense in depth: middleware AND route handler both verify auth (Convex variant)
- [ ] PIN env var not set → auth disabled (for local dev), not error
- [ ] Error messages in production are generic ("Internal server error")
