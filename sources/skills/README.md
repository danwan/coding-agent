# Authored Skills

Local-authored skills maintained in this repo. Each lives under
`sources/skills/<name>/SKILL.md` and is placed into `~/.agents/skills/`
(the canonical hub) by the setup prompt. From there it is linked into every
installed tool's skill dir (`~/.claude/skills`, `~/.codex/skills`,
`~/.cursor/skills`, `~/.gemini/antigravity-cli/skills`). OpenCode reads
`~/.agents/skills/*/SKILL.md` directly — no per-tool dir needed.

Remote skills (installed via `npx skills add`) are declared as intent in
`PROVISION.md`, not here.

## Inventory (9 skills)

| Skill | Purpose |
| --- | --- |
| `branch-cleanup` | Converge a messy git repo onto clean main: audit branches/PRs, plan merge order, auto-merge green PRs, prune gone/merged branches. Dry-run-able. |
| `config-edit` | Reference for path syntax in Claude Code `settings.json` and hooks (permissions, sandbox, hook paths, directory patterns). |
| `convexcheck` | Audit the current project's deploy setup (Convex + Vercel + Modal + shell) for footguns from `deploy-safety.md`. Report-only. |
| `deploy` | Safe Modal/Convex backend deployment. Delegates to project deploy scripts that own the 10-gate safety contract. |
| `git-sync` | Sync all git repos in the current directory across machines, or check their state. Triggers: "git sync", "Feierabend", "guten Morgen". |
| `notion-safe-writes` | Safe-write guardrails for the Notion MCP. Prevents known Notion MCP write bugs (literal \u-escapes, silent search-replace skips, child-page deletion). |
| `pin-auth` | Add PIN-based authentication to Next.js web apps. Two variants: Convex (DB sessions, fingerprinting, persistent rate limiting) and Lightweight (HMAC cookies, in-memory rate limiting). |
| `review-routing` | Routing lookup for review and security tools. Resolves which engine is the DEFAULT for a quick diff review, simplify, or security scan. |
| `stack-detection` | Verify which stack components (Convex, Vercel, Modal, Next.js, …) a project actually uses before applying stack-specific rules. |

## Lifecycle

- **New authored skill**: create `sources/skills/<name>/SKILL.md`, have the
  setup prompt place it under `~/.agents/skills/`, commit. The skill is
  immediately available to all tools.
- **Edit an authored skill**: edit the live file under `~/.agents/skills/<name>/`
  (that is what agents load), then copy the change into this repo and commit.
  The repo is the documented backup, NOT live-linked — no symlinks may point
  from the machine into this repo.
- **Retire a skill**: remove it from `~/.agents/skills/`, remove every harness
  symlink that pointed at it, then delete it here and from `PROVISION.md`.
