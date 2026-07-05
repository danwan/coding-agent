# OpenCode configuration — translation reference

This directory holds the authored OpenCode config that mirrors Danny's Claude
Code setup as closely as OpenCode's config schema allows. The repo is the
source of truth; live config at `~/.config/opencode/` symlinks into here
(authored files) or is rendered from `opencode.json.template` (secret-bearing).

This document records **what** was translated, **how** it is wired, and **why**
each approach was chosen — plus the features that have no OpenCode equivalent
(accepted architectural divergences).

## Symlink vs template — how each piece is tracked

The repo follows one principle: **authored config is symlinked (edit live =
edit repo); secret-bearing config is templated (copy once, never commit the
rendered copy).**

| Item | Repo home (tracked) | Live path | Mechanism |
| --- | --- | --- | --- |
| Master instructions | `sources/opencode/AGENTS.md` | `~/.config/opencode/AGENTS.md` | symlink (`apply.sh`) |
| Subagents | `sources/opencode/agents/` | `~/.config/opencode/agents` | symlink dir |
| Commands | `sources/opencode/command/` | `~/.config/opencode/command` | symlink dir |
| Safety-hooks plugin | `sources/opencode/plugin/safety-hooks.js` | `~/.config/opencode/plugin/` | symlink dir; referenced as `./plugin/safety-hooks.js` in `plugin:[]` |
| `opencode.json` | `sources/opencode/opencode.json.template` | `~/.config/opencode/opencode.json` | **template** (copy once; `{{HOME}}` + `{{CONTEXT7_API_KEY}}` substituted) — contains a secret + machine-specific node_repl env, so it cannot be symlinked |
| Format scripts | `sources/claude/hooks/format-{python,typescript}.sh` | `~/.claude/hooks/...` (already symlinked) | **reused** — OpenCode reaches `~/.claude/**` via the `external_directory` allowlist; the scripts are dual-mode (Claude is master for shared authored config) |
| PreToolUse scripts | `sources/claude/hooks/{pre-publish-secret-scan,check-backend-deploy}.sh` | `~/.claude/hooks/...` (already symlinked) | **reused** — the safety-hooks plugin shells out to them; canonical logic stays in one place |

**Net new tracked files in this translation:** `sources/opencode/plugin/safety-hooks.js`,
`sources/opencode/command/{commit,commit-push-pr,clean_gone}.md`, this README.
**Net new symlinks:** `~/.config/opencode/plugin`, `~/.config/opencode/command`.

## Feature mapping — Claude Code → OpenCode

### Already aligned (no change needed)

| Claude Code | OpenCode | Notes |
| --- | --- | --- |
| Master rules (`CLAUDE.md` + `rules/*.md`) | `instructions: ["AGENTS.md","~/.agents/AGENTS.md","~/.claude/rules/*.md"]` | Glob loading confirmed in OpenCode schema. All 11 project rules + 13 golden rules load identically. |
| Subagents (challenger, codebase-audit, git-status, learner) | `sources/opencode/agents/*.md` | Bodies byte-identical to Claude (claude is master; `apply.sh` checks drift). |
| Skills | auto-loaded from `~/.claude/skills/*/SKILL.md` AND `~/.agents/skills/*/SKILL.md` | All 44 skills reachable (authored + remote + 3 memsearch-bundled). |
| memsearch plugin | `@zilliz/memsearch-opencode` (npm) | Equivalent to Claude's `memsearch@memsearch-plugins`; bundles the same 3 skills. |
| LSP | `lsp: true` | Covers Claude's `typescript-lsp` + `pyright-lsp` plugins via built-ins. |
| Permission deny-list | `permission.bash: {rm -rf/r/sudo/chmod 777 → deny}` | Mirrors Claude's `permissions.deny`. |
| `external_directory` allowlist | `permission.external_directory` | `~/code/**, ~/.claude/**, ~/.agents/**, /tmp/**`. OpenCode reaches the shared hooks/scripts through this. |
| MCP `context7` | `mcp.context7` (remote) | Identical URL + header auth. |

### Added by this translation

| Claude Code | OpenCode | Wiring | Why this approach |
| --- | --- | --- | --- |
| MCP `notion` (remote, OAuth) | `mcp.notion` | `type:"remote"` in template (OAuth auto-detected by default; omit `oauth` field — schema only allows `oauth:false` to disable, or an object; `true` is invalid) | Notion's server handles the OAuth browser flow. |
| PreToolUse `pre-publish-secret-scan.sh` | `tool.execute.before` plugin | `sources/opencode/plugin/safety-hooks.js` shells out to the canonical script | The script's stdin-JSON/exit-2 contract is Claude-specific, so a thin adapter synthesizes that shape and **throws** to block (confirmed viable via opencode's `env-protection.js` example). Logic stays in the script — never duplicated. |
| PreToolUse `check-backend-deploy.sh` | same plugin, git-push branch | pre-filter `/git\s+push/`, call script, print `warn` to stderr | The script doesn't self-scope by command, so the plugin pre-filters (mirrors Claude's `if: Bash(git push*)`). |
| PostToolUse `format-python.sh` / `format-typescript.sh` | `formatter` object | `opencode.json` `formatter.{ruff,prettier-ts}` with `$FILE` arg | OpenCode's formatter runs custom commands per-extension on every write/edit in the background — a config-only equivalent of the hooks. **No plugin needed.** Scripts made dual-mode (accept `$1` as filepath, fall back to stdin JSON) so they stay backward-compatible with Claude. |
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
| `SessionStart` hook (`session-start.sh` git summary) | OpenCode's `event` hook fires for every bus event (no dedicated session-start hook); the value is low in OpenCode's TUI. **Decision: skip (4b).** The script remains canonical for Claude. |
| MCP servers: Exa, Gmail, Google Calendar, Drive, n8n, Sentry | Roam via claude.ai login (account-bound); no portable standalone equivalent. |
| MCP `node_repl` (Codex CUA binary) | **Deliberately omitted.** OpenCode ships a native `node_repl_js` tool (and `node_repl_js_add_node_module_dir`, `node_repl_js_reset`) — no MCP server needed. Claude Code uses the Codex.app-bundled `node_repl` binary as a shortcut (Claude lacks native JS exec), but that cross-tool binary dependency is fragile and redundant in OpenCode. |
| Plugins: pr-review-toolkit, frontend-design, skill-creator, coderabbit, superpowers, ponytail | Claude-Code-marketplace-only; no npm/OpenCode build. ponytail (live session log) and coderabbit (PR review API) could be reimplemented as OpenCode plugins, but that is net-new work, not config. |

## Secret / template contract

- `opencode.json.template` uses `{{HOME}}` (auto-substituted by `apply.sh`) and
  `{{CONTEXT7_API_KEY}}` (manual — get from password manager / chat, never
  commit the value).
- The rendered `~/.config/opencode/opencode.json` is a **secret-bearing copy**
  that must never be committed. `apply.sh` only writes it if missing; it never
  overwrites a differing live file (reports a `[CONFLICT]` instead).
- The safety-hooks plugin and the format scripts contain **no secrets** —
  they are symlinked, so editing the repo edits them live.

## Runtime assumptions to confirm on first run

1. **`tool.execute.before` bash args shape** — the plugin reads
   `output.args.command` (string) with an `output.args.commands` (array)
   fallback. If OpenCode's bash tool uses a different arg name, secret-scan
   will silently no-op. Verify at the gate below; adjust the `bashCommand()`
   helper if needed.
2. **node_repl env drift** — `NODE_REPL_TRUSTED_BROWSER_CLIENT_SHA256S` and
   `BROWSER_USE_CODEX_APP_VERSION` are version-specific; refresh from
   `~/.codex/config.toml` after Codex updates.
3. **Plugin double-load** — if OpenCode auto-discovers `~/.config/opencode/plugin/`
   AND honors the explicit `plugin:[]` entry, the hook could fire twice.
   If observed, drop `"./plugin/safety-hooks.js"` from the array and rely on
   auto-discovery (or vice-versa).

## Verification checklist (after `./scripts/apply.sh`)

1. `./scripts/apply.sh --check` → `0 pending action(s)`, only expected todos.
2. Start opencode, run `/commit` → confirm the command loads and stages+commits.
3. Edit a `.py` and a `.ts`/`.tsx` file → confirm ruff / prettier fire (formatter).
4. Run `git commit -m "test sk-ant-api03-FAKEKEY"` (fake secret) → confirm the
   plugin **blocks** (throws) — proves the secret-scan path works.
5. `git push` in a repo with undeployed `convex/` changes → confirm the deploy
   warning surfaces on stderr.
6. `/mcp` (or equivalent) → confirm `context7`, `notion`, `node_repl` connect.
7. Spot-check skills list → all 44 still present (memsearch 3 included).

## Sources (research-based, not memory)

- OpenCode JSON Schema: `https://opencode.ai/config.json` (fetched live).
- OpenCode plugin Hooks interface + `env-protection.js` throw-to-block example:
  `/anomalyco/opencode` via Context7 (`packages/web/src/content/docs/plugins.mdx`).
- Formatter custom-command contract: `formatters.mdx` (`$FILE` substitution,
  per-extension, background).
- `customize-opencode` built-in skill (authoritative config reference).
- Live Claude config: `~/.claude/settings.json`, `~/.claude.json`,
  `~/.codex/config.toml`, `manifest/*`.
- OpenCode version tested: **1.17.12**.
