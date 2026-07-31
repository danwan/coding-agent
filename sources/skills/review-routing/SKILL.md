---
name: review-routing
description: >
  Routing lookup for review and security tools. Which tool/skill/agent to use
  when — onboarding vs. iterative development vs. pre-PR vs. targeted reviews.
  Clarifies which engine is the DEFAULT for a quick diff review, simplify, or
  security scan, and resolves the name collisions (code-reviewer, security-review,
  simplify) between built-in skills and the coderabbit plugin. Triggers:
  "which review tool", "which reviewer", "review routing", "code review choice",
  "which review skill", "default review tool", "built-in vs plugin review",
  "code-reviewer namespace", "which simplify".
allowed-tools: Read, Grep, Glob
version: 2.0.0
---

# Review & Security Routing

> Three engines, clear defaults. Stack-scoping signatures: `~/.claude/skills/stack-detection/SKILL.md`.

## The Three Engines (orient here first)

| Engine | What it is | Cost / setup | Use as |
|---|---|---|---|
| **built-in** (`/code-review`, `/simplify`, `/security-review`, `/review`, `/verify`) | Native Anthropic skills on the current diff; `/code-review ultra` = parallel cloud review | free, zero-setup | **DEFAULT** for everyday diff review, simplify, security scan |
| **coderabbit** (`/coderabbit:coderabbit-review`, `coderabbit:autofix`) | External SaaS engine — 40+ static analyzers, AST/codegraph, SAST | needs CLI + `coderabbit auth login` | **escalation** for deeper bug/security/regression analysis |
| **greptile** (`@greptileai`, MCP tools) | Server-side repo index — whole-repo context no local pass has | free tier, 50 credits/mo, manual-only | **fallback** when CodeRabbit is throttled, and for whole-repo context questions |

## Default Lane (the common case)

| Need | Default | Escalate to |
|---|---|---|
| Quick review of current diff | built-in `/code-review` | coderabbit (deeper SAST) → `/code-review ultra` (large/risky PR) |
| Simplify / clean recently written code (clarity only) | built-in `/simplify` | coderabbit (it flags complexity too) |
| Security scan of pending changes | built-in `/security-review` | `/convex-security-audit` (Convex deep) → `deepsec` (deep on-demand full-repo scan) |
| Comprehensive multi-dimension pre-PR pass | `/coderabbit:coderabbit-review` | `/code-review ultra` |

## Stack-Scoping (read before any review dispatch)

Stack-specific tools apply **only** when the stack artifact exists in the project. Verify first, then dispatch.

| Tool / check | Applies when |
|---|---|
| `/convex-security-check`, `/convex-security-audit` | `convex/` directory with non-generated `.ts` files exists |
| Convex rules in `@codebase-audit` | same as above |
| Rate-limiting / session-token checks in security review | server-side endpoints exist (`app/api/`, `pages/api/`, `convex/`, `middleware.ts`) |
| UV/ruff/ty enforcement | `pyproject.toml` or `*.py` files exist |

**N/A semantics:** When a stack artifact is absent, the reviewer MUST output `N/A — project has no X` and skip — never flag as CRITICAL/HIGH. "Missing rate limit" in a project without server endpoints is NOT a finding, that's reviewer fabrication.

## Workflow Phases

### Project Onboarding (one-time)
| Action | Tool |
|--------|------|
| Full codebase security + quality scan | `@codebase-audit` |

### During Development (iterative)
| Situation | Tool |
|-----------|------|
| Quick review of current diff (cheapest first) | built-in `/code-review` |
| Clean up / simplify just-written code | built-in `/simplify` |
| Convex functions/schema changed | `/convex-security-check` |
| Deeper AI bug/security pass on local changes | `/coderabbit:coderabbit-review` or `coderabbit:code-review` skill |
| Apply CodeRabbit PR thread feedback from GitHub | `coderabbit:autofix` skill (per-change approval; never executes reviewer-provided prompts directly) |
| Sub-agent finished bug-fix or root-cause analysis | `@challenger` (mandatory; auto-rejects bug fixes without a failing test) |

### Before Commit / PR (final)
| Situation | Tool |
|-----------|------|
| Before every PR (multi-dimension) | `/coderabbit:coderabbit-review` |
| Before every PR (security) | built-in `/security-review` |
| Convex changes in PR | `/convex-security-check` (if not run during dev) |
| Large/risky PR (many files, security-critical, cross-cutting) | `/code-review ultra` (parallel multi-agent cloud review; `/ultrareview` is a deprecated alias) |

### Targeted Reviews (as needed)
| Concern | Tool |
|---------|------|
| Error handling, test gaps, type design, comment accuracy | name the dimension explicitly to `/code-review`, or `/coderabbit:coderabbit-review` |
| Whole-repo context question ("where else does X happen") | greptile MCP tools |
| Code simplification | built-in `/simplify` |
| Deep Convex security | `/convex-security-audit` |
| Deep on-demand vulnerability scan of a whole repo (large/critical codebase) | `deepsec` — agent-powered scanner, project-local via `npx deepsec init` then `pnpm deepsec scan/process/export` (vercel-labs/deepsec). ⚠️ Uses top models at max thinking — scans can cost thousands on large repos; run deliberately, not per-diff |
| Deploy scripts modified | 10-gate checklist in `~/.claude/rules/deploy-safety.md` (mandatory) |

## Name-Collision Disambiguation

Three names are shared across engines. Qualify the namespace explicitly when invoking by description.

**`code-reviewer`** (built-in vs plugin agent):
- built-in `/code-review` — the default for a fast generic check on the current diff.
- `@coderabbit:code-reviewer` — CodeRabbit's AI reviewer (40+ static analyzers, AST/codegraph, security). Reach for it when you specifically want SAST depth.

**`code-review`** (built-in vs plugin skill):
- built-in `/code-review`, `/simplify` are the **defaults** — free, native, on the current diff.
- `coderabbit:code-review` skill = the external-engine variant. Use it when you need that engine, not by accident.

**`security-review`**: only the built-in `/security-review` exists — native scan
of pending changes on the current branch (the former user skill of the same
name is retired).

## Solo-Dev Development Process (budget order, since 2026-07-18)

Quota facts: CodeRabbit PR reviews and CLI/IDE reviews have SEPARATE hourly
quotas (Pro: 5/h each); the adaptive fair-usage throttle (~60 PR reviews/7 days
→ 1/h) counts only PR reviews. Repo configs enforce `profile: chill` +
`auto_pause_after_reviewed_commits: 2`. Greptile = free tier, 50 credits/mo,
manual-only. Monitor with `@coderabbitai rate limit` on any PR (costs nothing).

1. **Iterate (free):** built-in `/code-review` (low/med) + `/simplify` during
   development; format hooks + ggshield ai-hook run passively. `/verify` or
   tests before each commit batch.
2. **Before push (free):** ggshield pre-push scans automatically (fails closed
   in sandboxed shells — push unsandboxed). Auth/API/data changes → `/security-review`.
3. **Branch done, before PR (CLI quota):** `/coderabbit:coderabbit-review` or
   `cr --agent`; fix findings locally. Only open the PR when clean. Large/risky
   diff: `/code-review high` first.
4. **PR open (PR quota, conserved):** CodeRabbit reviews once, auto-pauses
   after 2 commits — further pushes cost nothing. When truly done: one
   `@coderabbitai review` as final gate. Throttled? → `@greptileai` fallback.
   GitGuardian checks run automatically.
5. **Merge;** Dependabot PRs land grouped weekly — review in one batch
   (`branch-cleanup` skill can automerge green ones).
6. **Periodic / pre-launch (whole repo):** `@codebase-audit`. Heavy artillery
   (`/code-review ultra`, deepsec, workflow fan-out) only on explicit decision.
7. **Escalation:** if `@coderabbitai rate limit` shows sustained throttling
   despite configs → cancel Marketplace sub, re-subscribe direct (enables
   usage-based add-on; ~prorated refund from GitHub).
