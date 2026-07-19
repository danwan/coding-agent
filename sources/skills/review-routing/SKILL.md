---
name: review-routing
description: >
  Routing lookup for review and security tools. Which tool/skill/agent to use
  when — onboarding vs. iterative development vs. pre-PR vs. targeted reviews.
  Clarifies which engine is the DEFAULT for a quick diff review, simplify, or
  security scan, and resolves the name collisions (code-reviewer, security-review,
  simplify) between built-in skills, pr-review-toolkit, and coderabbit. Triggers:
  "which review tool", "which reviewer", "review routing", "code review choice",
  "which review skill", "default review tool", "built-in vs plugin review",
  "code-reviewer namespace", "which simplify".
allowed-tools: Read, Grep, Glob
version: 1.3.0
---

# Review & Security Routing

> Three engines, clear defaults. Stack-scoping signatures: `~/.claude/skills/stack-detection/SKILL.md`.

## The Three Engines (orient here first)

| Engine | What it is | Cost / setup | Use as |
|---|---|---|---|
| **built-in** (`/code-review`, `/simplify`, `/security-review`, `/review`, `/verify`) | Native Anthropic skills on the current diff; `/code-review ultra` = parallel cloud review | free, zero-setup | **DEFAULT** for everyday diff review, simplify, security scan |
| **coderabbit** (`/coderabbit:coderabbit-review`, `coderabbit:autofix`) | External SaaS engine — 40+ static analyzers, AST/codegraph, SAST | needs CLI + `coderabbit auth login` | **escalation** for deeper bug/security/regression analysis |
| **pr-review-toolkit** (`/review-pr` + 6 agents) | Local rule-based agents | free, zero-setup | its **4 specialists** (tests/types/comments/silent-failures) are unique; `code-reviewer` + `code-simplifier` agents overlap built-in/coderabbit — not the default |

## Default Lane (the common case)

| Need | Default | Escalate to |
|---|---|---|
| Quick review of current diff | built-in `/code-review` | coderabbit (deeper SAST) → `/code-review ultra` (large/risky PR) |
| Simplify / clean recently written code (clarity only) | built-in `/simplify` | `pr-review-toolkit:code-simplifier` only as part of a full `/review-pr` run |
| Security scan of pending changes | built-in `/security-review` | user `security-review` skill (pre-merge checklist) → `/convex-security-audit` (Convex deep) → `deepsec` (deep on-demand full-repo scan) |
| Comprehensive multi-dimension pre-PR pass | `/review-pr` (6 pr-review-toolkit agents) | `/code-review ultra` |

## Stack-Scoping (read before any review dispatch)

Stack-specific tools apply **only** when the stack artifact exists in the project. Verify first, then dispatch.

| Tool / check | Applies when |
|---|---|
| `/convex-security-check`, `/convex-security-audit` | `convex/` directory with non-generated `.ts` files exists |
| Convex rules in `/review-pr`, `@codebase-audit` | same as above |
| Modal cold-start / image checks in `/performance-review` | `modal` referenced in `pyproject.toml` or Python imports |
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
| Plan step / milestone completed | `superpowers:requesting-code-review` |
| Review feedback received | `superpowers:receiving-code-review` |
| Convex functions/schema changed | `/convex-security-check` |
| Deeper AI bug/security pass on local changes | `/coderabbit:coderabbit-review` or `coderabbit:code-review` skill |
| Apply CodeRabbit PR thread feedback from GitHub | `coderabbit:autofix` skill (per-change approval; never executes reviewer-provided prompts directly) |
| Sub-agent finished bug-fix or root-cause analysis | `@challenger` (mandatory; auto-rejects bug fixes without a failing test) |

### Before Commit / PR (final)
| Situation | Tool |
|-----------|------|
| Before every PR (multi-dimension) | `/review-pr` (6 pr-review-toolkit agents) |
| Before every PR (security) | built-in `/security-review`, then user `security-review` skill for the pre-merge checklist |
| Convex changes in PR | `/convex-security-check` (if not run during dev) |
| Performance-sensitive changes | `/performance-review` |
| Large/risky PR (many files, security-critical, cross-cutting) | `/code-review ultra` (parallel multi-agent cloud review; `/ultrareview` is a deprecated alias) |

### Targeted Reviews (as needed)
| Concern | Tool |
|---------|------|
| Error handling / catch blocks | `pr-review-toolkit:silent-failure-hunter` |
| Test coverage gaps | `pr-review-toolkit:pr-test-analyzer` |
| Type design / invariants | `pr-review-toolkit:type-design-analyzer` |
| Comment accuracy | `pr-review-toolkit:comment-analyzer` |
| Code simplification | built-in `/simplify` (default); `pr-review-toolkit:code-simplifier` inside a `/review-pr` run |
| Deep Convex security | `/convex-security-audit` |
| Deep on-demand vulnerability scan of a whole repo (large/critical codebase) | `deepsec` — agent-powered scanner, project-local via `npx deepsec init` then `pnpm deepsec scan/process/export` (vercel-labs/deepsec). ⚠️ Uses top models at max thinking — scans can cost thousands on large repos; run deliberately, not per-diff |
| Deploy scripts modified | 10-gate checklist in `~/.claude/rules/deploy-safety.md` (mandatory) |

## Name-Collision Disambiguation

Three names are shared across engines. Qualify the namespace explicitly when invoking by description.

**`code-reviewer`** (agent name shared by two plugins):
- `@pr-review-toolkit:code-reviewer` — local rule-based reviewer (style, project conventions, CLAUDE.md compliance)
- `@coderabbit:code-reviewer` — CodeRabbit's AI reviewer (40+ static analyzers, AST/codegraph, security)
- For a fast generic check prefer built-in `/code-review`; reach for the plugin agents only when you specifically want convention-checking (pr-review-toolkit) or SAST (coderabbit). Running both before risky PRs is fine.

**`code-review` / `simplify`** (built-in vs plugin):
- built-in `/code-review`, `/simplify` are the **defaults** — free, native, on the current diff.
- `coderabbit:code-review` skill = the external-engine variant; `pr-review-toolkit:code-simplifier` = the bundled-agent variant. Use these only when you need their specific engine, not by accident.

**`security-review`** (built-in vs user skill):
- built-in `/security-review` — native scan of pending changes on the current branch (run first).
- user `security-review` skill — pre-merge checklists + audit commands for auth/data/API changes (the deeper, project-specific gate).

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
   diff: `/review-pr` specialists or `/code-review high` first.
4. **PR open (PR quota, conserved):** CodeRabbit reviews once, auto-pauses
   after 2 commits — further pushes cost nothing. When truly done: one
   `@coderabbitai review` as final gate. Throttled? → `@greptileai` fallback.
   Aikido + GitGuardian checks run automatically.
5. **Merge;** Dependabot PRs land grouped weekly — review in one batch
   (`branch-cleanup` skill can automerge green ones).
6. **Periodic / pre-launch (whole repo):** `@codebase-audit` + `/ponytail-audit`,
   then `/performance-review`. Heavy artillery (`/code-review ultra`, deepsec,
   workflow fan-out) only on explicit decision.
7. **Escalation:** if `@coderabbitai rate limit` shows sustained throttling
   despite configs → cancel Marketplace sub, re-subscribe direct (enables
   usage-based add-on; ~prorated refund from GitHub).
