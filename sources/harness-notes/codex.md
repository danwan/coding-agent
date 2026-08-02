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
  place the full references under `~/.codex/rules/`, matching `sync.sh`.
  Copy **all** rules — do not silently drop any.
- **Subagents:** `sources/claude/agents/*.md` → your TOML agent definitions.
  Store standalone files under `~/.codex/agents/`. Preserve intent, but adapt
  Claude-only tools, paths, lifecycle names, and unsupported constraints.
- **Skills:** placed in the shared `~/.agents/skills/` hub; link into your skills dir.
  Skip optional skills marked Claude-only in `PROVISION.md`, and do not install
  stored-but-disabled skills. Because Codex also discovers the shared hub,
  remove obsolete `~/.codex/skills/` links and add `[[skills.config]]` entries
  with `enabled = false` for every shared-hub skill that must stay available to
  another harness but disabled in Codex.
- **Browser tooling:** keep the three surfaces distinct: desktop Browser
  (app-only), Chrome plugin (existing user Chrome), and the standalone
  `agent-browser` CLI (headless usability automation). The capability comes from
  the `agent-browser` CLI plus the separately installed remote skill — **not**
  from a Vercel Codex plugin, which is not installed here (see PROVISION.md, MCP
  section: none of the OpenAI-curated connectors is installed). This setup keeps
  `agent-browser` and `agent-browser-verify` globally active.
  *If* a Vercel connector is ever installed: check `codex plugin list` first,
  then trim its bundled skills with `[[skills.config]]` while keeping the
  connector enabled, and re-check those overrides after every plugin update —
  updates move the cached skill paths.
- **Hooks:** keep only the external Orca integration hooks from
  `~/.orca/agent-hooks/`. Do not restore the retired backend-deploy or
  pre-publish secret-scan hooks; their surviving policy belongs in rules and
  normal git tooling.

## Frontmatter → TOML mapping (map to your current keys, don't pin values)
| Claude frontmatter | Codex equivalent |
| --- | --- |
| `name`, `description` | required top-level TOML fields |
| `model: haiku\|sonnet\|opus` | your nearest model **tier** — resolve the current model id yourself, don't hardcode one |
| `effort: low\|medium\|high` | `model_reasoning_effort` |
| `tools:` allow-list | no custom-agent equivalent; tool access is session/sandbox-controlled, so adapt the behavioral intent instead of copying tool names |
| `maxTurns` | no custom-agent equivalent; omit it |
| body (markdown) | `developer_instructions` as a TOML multiline string |

## No direct equivalent — skip or degrade gracefully

Claude `settings.json` permission/sandbox/env blocks and `statusLine`. Configure
the analogous Codex setting only when current Codex documentation defines one.
