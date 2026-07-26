# Codex — translation notes

You are translating the canonical `sources/claude/` content into Codex's format.
Check your **own current docs** for exact paths/keys — the below is the durable
mapping, not a schema you should copy verbatim.

## Where things go
- **Shared CLI/app state:** on one machine, Codex CLI and the Codex desktop app
  share `~/.codex/config.toml`, global MCP configuration, `AGENTS.md`, agents,
  and skills. The app can additionally expose account-delivered plugins and an
  app-only Browser surface; verify both inventories instead of creating a
  second app-specific config.
- **Global instructions:** `sources/claude/CLAUDE.md` → `~/.codex/AGENTS.md`.
- **Rules:** the files in `sources/claude/rules/` are always-loaded guidance.
  Codex does not import arbitrary Markdown files from `AGENTS.md`. Fold a
  compact but complete statement of every binding rule into `AGENTS.md`, then
  place the full adapted references under `~/.codex/guidance/` and link them.
  Copy **all** rules — do not silently drop any.
- **Runbooks:** `sources/claude/runbooks/` are consult-on-demand references;
  adapt paths and agent-specific claims, place them under
  `~/.codex/runbooks/`, and link them from `AGENTS.md`.
- **Subagents:** `sources/claude/agents/*.md` → your TOML agent definitions.
  Store standalone files under `~/.codex/agents/`. Preserve intent, but adapt
  Claude-only tools, paths, lifecycle names, and unsupported constraints.
- **Skills:** placed in the shared `~/.agents/skills/` hub; link into your skills dir.
  Skip optional skills marked Claude-only in `PROVISION.md`, and do not install
  stored-but-disabled skills.
- **Hooks:** translate the four authored hooks into Codex's current hook schema
  under `~/.codex/hooks.json`; keep adapted scripts under
  `~/.codex/hooks/`. Hooks require explicit trust in a fresh Codex session.
- **Browser tooling:** keep the three surfaces distinct: desktop Browser
  (app-only), Chrome plugin (existing user Chrome), and the standalone
  `agent-browser` CLI (headless usability automation). The Vercel Codex plugin
  supplies the relevant skills; no duplicate global skill is needed. Disable
  unused bundled Vercel skills with `[[skills.config]]` while keeping the
  connector enabled; this setup keeps only `agent-browser` and
  `agent-browser-verify` globally active.

## Frontmatter → TOML mapping (map to your current keys, don't pin values)
| Claude frontmatter | Codex equivalent |
| --- | --- |
| `name`, `description` | required top-level TOML fields |
| `model: haiku\|sonnet\|opus` | your nearest model **tier** — resolve the current model id yourself, don't hardcode one |
| `effort: low\|medium\|high` | `model_reasoning_effort` |
| `tools:` allow-list | no custom-agent equivalent; tool access is session/sandbox-controlled, so adapt the behavioral intent instead of copying tool names |
| `maxTurns` | no custom-agent equivalent; omit it |
| body (markdown) | `developer_instructions` as a TOML multiline string |

## Hook translation notes

- Claude's `if` handler filter is not a Codex field. Put command/path filtering
  inside the script.
- Codex matchers filter tool names, not the shell command itself.
- For `apply_patch`, extract affected paths from the patch text in
  `tool_input.command`; do not expect Claude's `file_path`.
- Emit Codex hook output fields, not Claude's `result` shape.
- Merge GitGuardian's native Codex hooks with the authored hook file instead of
  replacing either set.

## No direct equivalent — skip or degrade gracefully

Claude `settings.json` permission/sandbox/env blocks and `statusLine`. Configure
the analogous Codex setting only when current Codex documentation defines one.
