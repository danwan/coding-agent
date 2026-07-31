# System Verification Prompt

Verify this machine against `PROVISION.md` and the selected optional
items/modules. Do not treat an unselected optional item as a failure.

Print one concise line per check:

`[CATEGORY] <item> — PASS | FAIL | SKIP — <evidence or reason>`

Never print secret values, literal auth headers, tokens, or keychain contents.

## 0. Identify the environment

- Report the active coding agent, exact version, OS/version/architecture, shell,
  and package manager.
- Read the current agent's official documentation before assuming config paths
  or schema.
- State which optional items and modules were selected.

## 1. CLI defaults

Resolve each default tool against the canonical source in `PROVISION.md`, then
run its version/help check: `git`, `gh`, `rg`, `fd`, `ast-grep`, `jq`, `tree`,
`tmux`, `tailscale`, `micro`, `uv`, `fnm`, `bun`, `op`, `qmd`, `npx skills`,
`agent-browser`, and `ggshield`.

Additional checks:

- `agent-browser doctor --offline --quick` passes and a short session can open
  `https://example.com`, read its title, and close cleanly.
- `ggshield api-status` is healthy. Check `ggshield quota`; enabled Git and
  agent hooks are a FAIL when quota is zero because they cannot scan reliably.
- Verify every selected optional CLI/module tool in the same way.

## 2. Authored configuration

- Global instructions exist in the path used by this harness.
- Every canonical rule in `sources/claude/rules/` is represented in the active
  always-loaded instructions and the full adapted references are available.
- All four custom agents load in the harness's native format.
- No lifecycle hooks are configured (they were retired 2026-07-31); a hook
  wired in settings whose script no longer exists is a FAIL.
- The three default own skills are present exactly once:
  `branch-cleanup`, `git-sync`, `stack-detection`.
- `./sync-agents.py` (no argument) reports `zu schreiben: 0`, and every
  generated `~/.codex/agents/*.toml` parses as TOML with a non-empty
  `developer_instructions`.
- `./sync.sh` (no argument) reports `zu schreiben: 0` — every installed harness
  already carries the current authored content. A non-zero count means drift,
  not a failure of this check.
- No skill directory contains a dangling symlink:
  `find ~/.claude/skills ~/.agents/skills ~/.codex/skills ~/.cursor/skills ~/.gemini/antigravity-cli/skills -maxdepth 1 -type l ! -exec test -e {} \; -print`
  prints nothing.
- `npx skills update -g -y` reports all tracked remote skills current, and its
  lock contains no retired repository source.

## 3. MCP and plugins

- Context7 is configured using OAuth/keychain where supported, exposes tools,
  and completes one library-resolution call. A literal API key in a config file
  is a FAIL when OAuth is available.
- Verify optional Playwright and Google Developer Knowledge only when selected.
- For every configured MCP/plugin connector, run one harmless read-only call.
- Flag stale disabled direct servers and unauthenticated duplicate raw MCP legs.
  Prefer a working app connector unless the raw leg adds a required capability.

## 4. Codex-specific checks

When the active harness is Codex:

- Confirm CLI and desktop app use the same `~/.codex/config.toml`; do not create
  a second app-only MCP config.
- Run `codex --strict-config` validation and `codex doctor --summary`.
- Parse every `~/.codex/agents/*.toml` and require `name`, `description`, and
  `developer_instructions`.
- Confirm Browser works in the desktop app, Chrome works through the Chrome
  plugin, and the standalone `agent-browser` CLI works independently.
- Confirm OpenAI-curated GitHub, Gmail, Google Calendar, Google Drive, Notion,
  and Vercel app plugins are installed/enabled when this setup selected them.
- Ensure Claude-only command/agent/hook plugins are not installed into Codex.

## 5. Shell and personal toggle

Only when the personal toggle was selected:

- Compare the live shell aliases/functions with `sources/shell/aliases.zsh`.
- Verify SSH tmux auto-attach and Tailscale SSH without changing sudo-protected
  state during a verification-only run.
- Verify selected terminal/settings templates after placeholder substitution.

## 6. Final synthesis

- Compare installed state with selected `PROVISION.md` intent.
- List remaining FAIL items with exact remediation.
- List extras separately; do not delete them during a verification-only run.
- A final PASS requires concrete command/tool evidence and no skipped required
  check.
