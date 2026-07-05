---
name: performance-review
description: Automated performance review for Next.js + Convex + Modal stack. Runs actual checks on bundle size, Convex query patterns, React anti-patterns, and Modal cold-start risks. Triggers - "performance review", "check performance", "before launch performance", "perf check".
allowed-tools: Read, Grep, Glob, Bash, AskUserQuestion
version: 2.0.0
effort: high
---

# Performance Review

> Profile first, optimize second. Never recommend memoization without measurement evidence.

## Scope Detection (per `~/.claude/rules/stack-detection.md`)

Run first; skip sections whose stack artifact is absent. **Output skipped sections explicitly as "N/A — no <stack>".**

```bash
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo main)
git diff "$DEFAULT_BRANCH"...HEAD --name-only
```

| Stack | Signature |
|---|---|
| Next.js | `package.json` has `"next"` |
| Convex | `convex/` exists with non-generated `.ts` |
| Modal | `pyproject.toml` mentions `modal` OR `import modal` |

## Frontend (Next.js)

**Bundle chunks** — `ls -laS .next/static/chunks/ 2>/dev/null | head -20`. ≥1 MB = CRITICAL, 500 KB-1 MB = REVIEW.

**Missing `next/image`** — `grep -rn '<img ' --include='*.tsx' app/ src/ components/`. Each `<img>` outside `next/image` is a finding (except email templates / SVG sprites).

**Inline JSX literals** (only flag if component is render-hot) — `grep -rn -E 'style=\{\{|=\{\[' --include='*.tsx' app/ src/ components/`.

**Missing list keys** — `grep -rn -B1 '\.map(' --include='*.tsx' app/ src/ components/ | grep -A1 '\.map((' | grep -v 'key='`.

**Anti-pattern guardrail (CRITICAL):** Never recommend `memo`/`useMemo`/`useCallback` without (1) a measured slow render in React DevTools Profiler AND (2) evidence the wrapper is the bottleneck. Premature memoization causes stale-data bugs harder to find than the perf problem they "solve."

## Backend Convex

**Queries without indexes** — `grep -rn 'ctx\.db\.query' convex/ | grep -v 'withIndex'`. Each = full table scan. Acceptable only for lookup tables <1000 rows.

**Unbounded `.collect()`** — `grep -rn '\.collect()' convex/ | grep -v '\.take('`. Justify or replace with `.take()` / pagination.

**N+1 patterns** — `grep -rn -B2 'ctx\.db\.\(query\|get\)' convex/ | grep -B2 'for.*of\|forEach\|\.map'`. Replace with single indexed query or batch fetch.

**Compound indexes** — for queries filtering on multiple fields, cross-reference `convex/schema.ts`.

## Backend Modal

**Cold-start risk** — `grep -rn '@app\.function\|@stub\.function\|@modal\.method' --include='*.py'`. Latency-sensitive (user-facing API, webhooks): need `keep_warm >= 1`.

**Image bloat** — `grep -rn 'modal.Image' --include='*.py'`. Flag torch / tensorflow / full-CUDA installs; suggest slim base image or multi-stage build.

## Observability

Reference real p75 from Vercel Speed Insights (`https://vercel.com/{team}/{project}/analytics`): LCP ≤ 2.5 s, INP ≤ 200 ms, CLS ≤ 0.1. If not enabled, recommend enabling **before** optimizing.

## Output Format

```
## Performance Review Results

### CRITICAL (must fix before launch)
- {finding}: {file}:{line} — {explanation}

### REVIEW (investigate, may be acceptable)
- {finding}: {file}:{line} — {explanation}

### OK
- {section}: no issues found

### Skipped (N/A)
- {section}: no <stack> in project
```

End with one sentence: how many CRITICAL findings exist and whether the code is launch-ready.
