# Stack Detection (Verify Before Applying Stack-Specific Rules)

> **Purpose:** Prevent reviewer/auditor agents from fabricating stack dependencies based on the "Default Stack" in `~/.claude/CLAUDE.md`. The global default is not evidence — the project's actual files are. This file is linked from Golden Rule #8 and is the canonical reference for all stack-scoping decisions.
>
> **Reference implementer:** `performance-review/SKILL.md:13-26` already uses this pattern correctly — consult it for a working example.

## Core Rule

Before flagging a missing component or recommending a stack-specific fix, run the relevant detection command below. If the signature is absent, **do not flag**. State "N/A — project does not use X" in the output and skip the rule.

## Detection Signatures

Each signature is a single shell command that returns non-empty **only** when the corresponding stack component is actually present. Run at the project root (`git rev-parse --show-toplevel`).

### Next.js (frontend framework)
```bash
[ -f package.json ] && grep -q '"next"' package.json
```
**If absent:** do not apply Next.js-specific rules (RSC boundaries, `next/image`, `next.config.*` optimization, metadata, middleware).

### Server-side endpoints (rate limiting, auth, request handling)
```bash
# Any of these indicates a server-side attack surface:
[ -d app/api ] || [ -d pages/api ] || [ -d convex ] || \
  [ -f middleware.ts ] || [ -f middleware.js ] || \
  ls app/**/route.ts pages/api/**/*.ts 2>/dev/null | head -1
```
**If absent:** do not demand rate limiting, session tokens, CSRF tokens, input validation on server-side. A static site with a third-party form handler has no server-side attack surface. See also the qualifier in `security.md` → "Rate Limiting".

### Convex (backend + DB)
```bash
[ -d convex ] && ls convex/*.ts convex/**/*.ts 2>/dev/null | grep -v '_generated' | head -1
```
**If absent:** do not apply Convex patterns (`withIndex`, `internalMutation`, `v.any()` audits, `.collect()` bounds, compound-index checks, schema validators). Do not delegate to `/convex-security-check` or `/convex-security-audit`.

### Modal (Python compute)
```bash
[ -f pyproject.toml ] && grep -q 'modal' pyproject.toml
# OR
grep -rq 'import modal\|from modal\|@app\.function\|@stub\.function' --include='*.py' . 2>/dev/null
```
**If absent:** do not apply Modal patterns (`keep_warm`, image bloat, `modal.Image` optimization, cold-start analysis, deploy gates for `.py` files).

### Python tooling (UV / ruff / pyright)
```bash
[ -f pyproject.toml ] || ls *.py **/*.py 2>/dev/null | head -1
```
**If absent:** do not enforce `uv run`, ruff lint, pyright type-check, or `.venv` conventions.

### Vercel (frontend host)
```bash
[ -f vercel.json ] || [ -f next.config.js ] || [ -f next.config.mjs ] || [ -f next.config.ts ]
```
**If absent:** do not reference Vercel deploy behavior, Edge Runtime constraints, `vercel env`, or Speed Insights.

### Database in general (not just Convex)
```bash
[ -d convex ] || [ -d prisma ] || [ -d drizzle ] || \
  grep -rq 'postgres\|mysql\|mongodb\|sqlite\|supabase' --include='*.ts' --include='*.js' --include='*.py' . 2>/dev/null
```
**If absent:** do not demand DB-level security (row-level auth, schema migrations, index audits) — there is no persistence layer to protect.

## Decision Flow for Reviewers

```
For each stack-specific rule you're about to apply:
  1. Run the detection signature from this file.
  2. If signature matches → apply the rule as normal.
  3. If signature does NOT match → output "N/A — project has no X" and skip.
  4. Never infer presence from the global "Default Stack" list.
```

## Anti-Patterns (reject in code review)

- **"Add rate limiting" for a project with no server endpoints.** Static sites and pure client-rendered pages cannot be rate-limited server-side.
- **"Add Convex/Modal-specific patterns" for a project that has neither.** Don't infer from Default Stack; apply only to detected stacks.
- **"Run `uv run pytest`" in a TypeScript-only project.** No Python → no UV.

## Output Template

When skipping a section due to stack absence, surface it explicitly: "N/A — project has no X". Turns silence into auditable evidence that stack was verified.

## See Also

- `~/.claude/CLAUDE.md` Golden Rule #8 "Stack-Verification" — the binding rule
- `~/.claude/rules/security.md` "Rate Limiting" — scoped version
- `claude-config/skills/performance-review/SKILL.md:13-26` — reference implementation
