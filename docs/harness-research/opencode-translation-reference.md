# OpenCode configuration — translation reference

> **Archived reference — historical, version-specific** (OpenCode 1.17.12).
> The durable, version-independent essentials now live in
> `sources/harness-notes/opencode.md`, which the setup prompt actually reads.
> This file is kept only for the detailed feature-mapping and the reasoning
> behind each accepted divergence. Re-verify against OpenCode's current schema
> (`https://opencode.ai/config.json`) before relying on specifics.

This directory holds the authored OpenCode config that mirrors Danny's Claude
Code setup as closely as OpenCode's config schema allows. The repo is the
source of truth; live config at `~/.config/opencode/` is placed by the setup
prompt (see repo root). Edits are file edits + commit — there is no separate
sync/apply step and no hook machinery in this setup (removed by design; see
`sources/claude/rules/secrets-in-git.md` for the current self-enforce model).

This document records **what** was translated, **how** it is wired, and **why**
each approach was chosen — plus the features that have no OpenCode equivalent
(accepted architectural divergences).

## What's tracked here

| Item | Repo home (tracked) | Live path |
| --- | --- | --- |
| Master instructions | `sources/opencode/AGENTS.md` | `~/.config/opencode/AGENTS.md` |
| Subagents | `sources/opencode/agents/` | `~/.config/opencode/agents` |
| Commands | `sources/opencode/command/` | `~/.config/opencode/command` |
| `opencode.json` | `sources/opencode/opencode.json.template` | `~/.config/opencode/opencode.json` — template, `{{HOME}}` + `{{CONTEXT7_API_KEY}}` substituted once; contains a secret, so the rendered copy is never committed |

**Net new tracked files in this translation:** `sources/opencode/command/{commit,commit-push-pr,clean_gone}.md`, this README.

## Feature mapping — Claude Code → OpenCode

### Already aligned (no change needed)

| Claude Code | OpenCode | Notes |
| --- | --- | --- |
| Master rules (`CLAUDE.md` + `rules/*.md`) | `instructions: ["AGENTS.md","~/.agents/AGENTS.md","~/.claude/rules/*.md"]` | Glob loading confirmed in OpenCode schema. All 11 project rules + 13 golden rules load identically. |
| Subagents (challenger, codebase-audit, git-status, learner) | `sources/opencode/agents/*.md` | Bodies byte-identical to Claude (Claude is master for shared authored content). |
| Skills | auto-loaded from `~/.claude/skills/*/SKILL.md` AND `~/.agents/skills/*/SKILL.md` | All 44 skills reachable (authored + remote + 3 memsearch-bundled). |
| memsearch plugin | `@zilliz/memsearch-opencode` (npm) | Equivalent to Claude's `memsearch@memsearch-plugins`; bundles the same 3 skills. |
| LSP | `lsp: true` | Covers Claude's `typescript-lsp` + `pyright-lsp` plugins via built-ins. |
| Permission deny-list | `permission.bash: {rm -rf/r/sudo/chmod 777 → deny}` | Mirrors Claude's `permissions.deny`. |
| `external_directory` allowlist | `permission.external_directory` | `~/code/**, ~/.claude/**, ~/.agents/**, /tmp/**`. |
| MCP `context7` | `mcp.context7` (remote) | Identical URL + header auth. |

### Added by this translation

| Claude Code | OpenCode | Wiring | Why this approach |
| --- | --- | --- | --- |
| MCP `notion` (remote, OAuth) | `mcp.notion` | `type:"remote"` in template (OAuth auto-detected by default; omit `oauth` field — schema only allows `oauth:false` to disable, or an object; `true` is invalid) | Notion's server handles the OAuth browser flow. |
| `commit-commands` marketplace plugin (`/commit`, `/commit-push-pr`, `/clean_gone`) | native OpenCode commands | `sources/opencode/command/*.md` | OpenCode has no Claude marketplace; the 3 slash commands are reproduced as native command files. Claude's `!`backtick`` dynamic context injection → explicit "run these first" instructions (OpenCode commands have no inline-eval syntax). |

### Accepted architectural divergences (no OpenCode schema field)

These Claude Code features have **no equivalent** in OpenCode's config schema
(`https://opencode.ai/config.json`, fetched and verified). "100% identical"
is reached for every feature that has a schema field; the rest are
architecturally exclusive to Claude Code and are documented here, not fixed.

| Claude Code feature | Why not portable |
| --- | --- |
| `sandbox.network.allowedDomains` + `sandbox.filesystem.allowWrite` + `enableWeakerNetworkIsolation` | OpenCode has no sandbox config field; `external_directory` is a permission boundary, not a network/filesystem sandbox. |
| `statusLine.command` (`statusline.sh`) | No `statusLine` field; OpenCode's TUI draws its own status area. |
| `env` block (`TMPPREFIX`, `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`) | No `env` config field. |
| TUI prefs (`theme`, `editorMode: vim`, `tui: fullscreen`, `prefersReducedMotion`) | No schema fields; OpenCode TUI is configured differently (or not at all via JSON). |
| `autoMemoryEnabled` / `autoDreamEnabled` | No schema fields (OpenCode has `compaction`, a different mechanism). |
| `effortLevel`, `plansDirectory`, `agentPushNotifEnabled`, `attribution`, `cleanupPeriodDays`, `skipDangerousModePermissionPrompt`, `skipWorkflowUsageWarning` | No schema fields. |
| Claude's SessionStart git-summary behavior | OpenCode's `event` hook fires for every bus event (no dedicated session-start hook); the value is low in OpenCode's TUI. **Decision: skip.** |
| MCP servers: Exa, Gmail, Google Calendar, Drive, n8n, Sentry | Roam via claude.ai login (account-bound); no portable standalone equivalent. |
| MCP `node_repl` (Codex CUA binary) | **Deliberately omitted.** OpenCode ships a native `node_repl_js` tool (and `node_repl_js_add_node_module_dir`, `node_repl_js_reset`) — no MCP server needed. Claude Code uses the Codex.app-bundled `node_repl` binary as a shortcut (Claude lacks native JS exec), but that cross-tool binary dependency is fragile and redundant in OpenCode. |
| Plugins: pr-review-toolkit, frontend-design, skill-creator, coderabbit, superpowers, ponytail | Claude-Code-marketplace-only; no npm/OpenCode build. ponytail (live session log) and coderabbit (PR review API) could be reimplemented as OpenCode plugins, but that is net-new work, not config. |

## Secret / template contract

- `opencode.json.template` uses `{{HOME}}` and `{{CONTEXT7_API_KEY}}`
  (manual — get from password manager / chat, never commit the value).
- The rendered `~/.config/opencode/opencode.json` is a **secret-bearing copy**
  that must never be committed.

## Verification checklist

1. Start opencode, run `/commit` → confirm the command loads and stages+commits.
2. `/mcp` (or equivalent) → confirm `context7` and `notion` connect.
3. Spot-check skills list → authored + remote skills all present.

## Sources (research-based, not memory)

- OpenCode JSON Schema: `https://opencode.ai/config.json` (fetched live).
- `customize-opencode` built-in skill (authoritative config reference).
- Live Claude config: `~/.claude/settings.json`, `~/.claude.json`.
- OpenCode version tested: **1.17.12**.
