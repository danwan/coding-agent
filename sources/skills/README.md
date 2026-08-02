# Authored Skills

Local-authored skills maintained in this repo. Each lives under
`sources/skills/<name>/SKILL.md` and is placed into `~/.agents/skills/`
(the canonical hub) by the setup prompt. From there it is linked into every
installed tool's skill dir (`~/.claude/skills`, `~/.codex/skills`,
`~/.gemini/antigravity-cli/skills`). OpenCode reads `~/.agents/skills/*/SKILL.md`
directly — no per-tool dir needed. Grok inherits `~/.claude/skills` and gets no
copies.

Remote skills (installed via `npx skills add -g`) are declared as intent in
`PROVISION.md`, not here.

**Global skills are a closed set.** Seven authored (below) plus six remote —
thirteen in total, listed in `PROVISION.md`. Everything else is installed
**project-local**, in the repo that needs it, and is not this setup's business.
Do not add a skill here to make it available everywhere; that decision is the
exception, not the default.

Two former skills became rules in 2026-08: `stack-detection` and
`review-routing`. Both are reference policy rather than an invokable procedure,
two subagents depend on the first, and rules reach every harness through
`sync.sh` without occupying a global skill slot. See `sources/claude/rules/`.

## Inventory (7 skills)

| Skill | Purpose |
| --- | --- |
| `branch-cleanup` | Converge a messy git repo onto clean main: audit branches/PRs, plan merge order, auto-merge green PRs, prune gone/merged branches. Dry-run-able. |
| `config-edit` | Reference for path syntax in Claude Code `settings.json` and hooks (permissions, sandbox, hook paths, directory patterns). |
| `convexcheck` | Audit the current project's deploy setup (Convex + Vercel + Modal + shell) for footguns from `deploy-safety.md`. Report-only. |
| `deploy` | Safe Modal/Convex backend deployment. Delegates to project deploy scripts that own the 10-gate safety contract. |
| `git-sync` | Sync all git repos in the current directory across machines, or check their state. Triggers: "git sync", "Feierabend", "guten Morgen". |
| `notion-safe-writes` | Safe-write guardrails for the Notion MCP. Prevents known Notion MCP write bugs (literal \u-escapes, silent search-replace skips, child-page deletion). |
| `pin-auth` | Add PIN-based authentication to Next.js web apps. Two variants: Convex (DB sessions, fingerprinting, persistent rate limiting) and Lightweight (HMAC cookies, in-memory rate limiting). |

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
  Leaving the symlink behind is the common mistake — it dangles silently until
  the `verify.md` check catches it.
