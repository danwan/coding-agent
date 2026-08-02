# Review & Security Routing

> Two engines, clear defaults. Stack-scoping signatures: `~/.claude/rules/stack-detection.md`.

## The Two Engines (orient here first)

| Engine | What it is | Cost / setup | Use as |
|---|---|---|---|
| **built-in** (`/code-review`, `/simplify`, `/security-review`, `/review`, `/verify`) | Native Anthropic skills on the current diff; `/code-review ultra` = parallel cloud review | free, zero-setup | **DEFAULT** for everyday diff review, simplify, security scan |
| **coderabbit** (`/coderabbit:coderabbit-review`, `coderabbit:autofix`) | External SaaS engine — 40+ static analyzers, AST/codegraph, SAST, Multi-Repo Analysis | needs CLI + `coderabbit auth login` | **escalation** for deeper bug/security/regression analysis, and for cross-repo breaking changes |

> **Greptile is out of scope since 2026-08-02.** It was a second AI reviewer on the
> same pull requests, and overlapping reviewers produce contradictory comments that
> get ignored wholesale. Its one unique capability — whole-repo context beyond the
> diff — is covered by CodeRabbit's Multi-Repo Analysis. Do not route to
> `@greptileai` or its MCP tools.

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
| Whole-repo context question ("where else does X happen") | `rg`/`ast-grep` locally; for cross-repo impact, CodeRabbit Multi-Repo Analysis |
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

Quota facts: CodeRabbit PR reviews, IDE reviews and CLI reviews have SEPARATE
hourly quotas (Pro: 5/h each, Pro+: 10/h each); the adaptive fair-usage throttle
counts only PR reviews and drops to 1/h above ~60 reviews per 7 days on Pro,
~90 on Pro+. Repo configs enforce `profile: chill` +
`auto_pause_after_reviewed_commits: 2`. Monitor with `@coderabbitai rate limit`
on any PR (costs nothing).

**Burst discipline:** opening several PRs at once burns the hourly PR quota in
minutes and the surplus gets throttled, not queued. Open them as **drafts** —
CodeRabbit skips drafts (`drafts: false`) — and flip them to ready one at a time.
Run `cr review` before pushing: it draws on the separate CLI quota.

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
   `@coderabbitai review` as final gate. Throttled? The review is deferred, not
   lost — re-trigger with `@coderabbitai review` once capacity returns, and do
   not merge unreviewed in the meantime. GitGuardian checks run automatically.
5. **Merge;** Dependabot PRs land grouped weekly — review in one batch
   (`branch-cleanup` skill can automerge green ones).
6. **Periodic / pre-launch (whole repo):** `@codebase-audit`. Heavy artillery
   (`/code-review ultra`, deepsec, workflow fan-out) only on explicit decision.
7. **Escalation:** if `@coderabbitai rate limit` shows sustained throttling
   despite configs → cancel Marketplace sub, re-subscribe direct (enables
   usage-based add-on; ~prorated refund from GitHub).
