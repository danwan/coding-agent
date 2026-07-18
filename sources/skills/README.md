# Authored Skills

Local-authored skills maintained in this repo. Each lives under
`sources/skills/<name>/SKILL.md` and is placed into `~/.agents/skills/`
(the canonical hub) by the setup prompt. From there it is linked into every
installed tool's skill dir (`~/.claude/skills`, `~/.codex/skills`,
`~/.cursor/skills`, `~/.gemini/antigravity-cli/skills`). OpenCode reads
`~/.agents/skills/*/SKILL.md` directly — no per-tool dir needed.

Remote skills (installed via `npx skills add`) are declared as intent in
`PROVISION.md` (the "Skills — remote meta" section), not here.

## Inventory (17 skills)

| Skill | Purpose |
| --- | --- |
| `branch-cleanup` | Converge a messy git repo onto clean main: audit branches/PRs, plan merge order, auto-merge green PRs, prune gone/merged branches. Dry-run-able. |
| `challenge` | Dispatch the `@challenger` subagent to stress-test another sub-agent's output against first-answer bias and the TDD-bug-fix gate. |
| `chrome-ui-explorer` | Explore and interact with web UIs via the Claude-in-Chrome extension. Claude-only exception: lives as a real dir in `~/.claude/skills/`, not in the `~/.agents/skills/` hub. |
| `code-search` | Routing guide for source-code search: rg, fd, ast-grep, jq, tree, and Explore-subagent vs direct Bash. |
| `config-edit` | Reference for path syntax in Claude Code `settings.json` and hooks (permissions, sandbox, hook paths, directory patterns). |
| `convex-vercel-setup` | Standardize, audit, scaffold, and migrate Vercel + Convex + optional Modal deployment configuration. |
| `convexcheck` | Audit the current project's deploy setup (Convex + Vercel + Modal + shell) for footguns from `deploy-safety.md`. Report-only. |
| `deploy` | Safe Modal/Convex backend deployment. Delegates to project deploy scripts that own the 10-gate safety contract. |
| `git-sync` | Sync all git repos in the current directory across machines, or check their state. Triggers: "git sync", "Feierabend", "guten Morgen". |
| `grill-me` | Interview the user relentlessly about a plan or design until reaching shared understanding. Stress-test plans, poke holes. |
| `notion-safe-writes` | Safe-write guardrails for the Notion MCP. Prevents known Notion MCP write bugs (literal \u-escapes, silent search-replace skips, child-page deletion). |
| `performance-review` | Automated performance review for Next.js + Convex + Modal stack. Checks bundle size, Convex query patterns, React anti-patterns, Modal cold-start risks. |
| `pin-auth` | Add PIN-based authentication to Next.js web apps. Two variants: Convex (DB sessions, fingerprinting, persistent rate limiting) and Lightweight (HMAC cookies, in-memory rate limiting). |
| `pr-workflow` | GitHub PR review comment replies via CLI. |
| `review-routing` | Routing lookup for review and security tools. Resolves which engine is the DEFAULT for a quick diff review, simplify, or security scan. |
| `security-review` | Pre-merge security checklists and audit commands (incl. the Next.js/Convex/Python Stack-Checkliste). Required before merging PRs that touch auth, data access, or APIs. |
| `stack-detection` | Verify which stack components (Convex, Vercel, Modal, Next.js, …) a project actually uses before applying stack-specific rules. Referenced by CLAUDE.md Golden Rule #8. |

## Lifecycle

- **New authored skill**: create `sources/skills/<name>/SKILL.md`, have the
  setup prompt place it under `~/.agents/skills/`, commit. The skill is
  immediately available to all tools.
- **Edit an authored skill**: edit the live file under `~/.agents/skills/<name>/`
  (that is what agents load), then copy the change into this repo and commit.
  The repo is the documented backup, NOT live-linked — no symlinks may point
  from the machine into this repo.
