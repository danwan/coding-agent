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
`tmux`, `micro`, `uv`, `fnm`, `bun`, `op`, `qmd`, `npx skills`,
`agent-browser`, and `ggshield`.

Additional checks:

- `agent-browser doctor --offline --quick` passes and a short session can open
  `https://example.com`, read its title, and close cleanly.
- `ggshield`: only the binary is required. Auth, quota and hooks are intentionally
  inactive (see `PROVISION.md`) — do not report that as a FAIL. Check them only if
  reactivation was selected, and then a hook installed while `ggshield quota` is
  zero IS a FAIL, because it cannot scan and blocks pushes.
- Verify every selected optional CLI/module tool in the same way.

## 2. Authored configuration

- Global instructions exist in the path used by this harness.
- Every canonical rule in `sources/claude/rules/` is represented in the active
  always-loaded instructions and the full adapted references are available.
- **No harness carries a rule that is NOT canonical.** Count the files: each
  rules directory holds exactly the four canonical rules (plus a harness's own
  files, e.g. Antigravity's `default.rules`). An extra `*.md` is a leftover from
  an older revision and a FAIL — three such files survived in Antigravity until
  2026-08-01 and were still being loaded into every session, pointing at rules
  and runbooks that no longer exist. `sync.sh` places files; it never deletes.
- All four custom agents load in the harness's native format (except Grok — see
  section 4b).
- The ADR and feature-spec templates are present in `~/.agents/templates/`.
- No **repo-authored** lifecycle hooks are configured (they were retired
  2026-07-31). The external Orca integration hooks under `~/.orca/agent-hooks/`
  are expected and are not a finding — Orca owns them. Any hook wired in settings
  whose script does not exist on disk is a FAIL.
- `~/.agents/skills/` holds **exactly thirteen** entries and no others — seven
  authored (`branch-cleanup`, `config-edit`, `convexcheck`, `deploy`, `git-sync`,
  `notion-safe-writes`, `pin-auth`) and six remote (`agent-browser`,
  `computer-use`, `orca-cli`, `orchestration`, `skill-development`,
  `vercel-optimize`). An extra entry means something was installed globally that
  belongs project-local; a missing one means a placement or `npx skills` install
  did not run:
  ```sh
  ls -1 ~/.agents/skills | wc -l   # 13
  ```
- The two rules that were skills until 2026-08 are present as rules, not skills:
  `~/.claude/rules/stack-detection.md` and `~/.claude/rules/review-routing.md`
  exist, and `~/.agents/skills/stack-detection` / `review-routing` do **not**.
- `./sync-agents.py` (no argument) reports `zu schreiben: 0`, and every
  generated `~/.codex/agents/*.toml` parses as TOML with a non-empty
  `developer_instructions`.
- `./sync.sh` (no argument) reports `zu schreiben: 0` — every installed harness
  already carries the current authored content. A non-zero count means drift,
  not a failure of this check.
- No skill directory contains a dangling symlink. Guard each path — on a machine
  where a harness is not installed, `find` errors out and exits non-zero, which
  reads as a failure of this check rather than an absent harness:
  ```sh
  for d in ~/.claude/skills ~/.agents/skills ~/.codex/skills ~/.grok/skills \
           ~/.gemini/antigravity-cli/skills; do
    [ -d "$d" ] && find "$d" -maxdepth 1 -type l ! -exec test -e {} \; -print
  done
  ```
  prints nothing. A hit means the skill hub lost the target — usually because a
  remote skill was retired while a per-harness link survived. Fix by re-running
  `./sync.sh --apply` (for authored skills) or `npx skills update -g -y` (for
  remote ones), then delete whatever still dangles.
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
- Run `codex doctor --summary`; `0 fail` is the bar. Warnings about rollout files
  or the state DB are Codex-internal session bookkeeping, not a config finding.
  (`codex --strict-config` needs a TTY and cannot be checked from a script.)
- Parse every `~/.codex/agents/*.toml` and require `name`, `description`, and
  `developer_instructions`.
- Confirm Browser works in the desktop app, Chrome works through the Chrome
  plugin, and the standalone `agent-browser` CLI works independently.
- `codex plugin list`: the OpenAI-curated app connectors are currently NOT
  installed — that is the recorded state, not a FAIL. Report any change in
  either direction, and check whether a newly installed connector duplicates an
  existing raw MCP leg (Notion in particular).
- The Claude-marketplace plugins listed in `PROVISION.md` are installed and
  enabled in Codex. This is intended: Codex runs them natively. A Claude plugin
  that is installed but NOT listed there is a prune candidate — ask, never
  auto-remove.

## 4b. Grok-specific checks

When the active harness is Grok:

- `grok inspect` lists the authored global rules **exactly once each**, sourced
  from the Claude compat scanner. A rule appearing twice means someone placed a
  copy under `~/.grok/rules/` — that directory must be empty.
- `~/.grok/config.toml` disables the Cursor compat cells (Cursor is out of scope,
  and its leftovers would otherwise still be loaded).
- The skills intentionally switched off in Claude's `skillOverrides` are also
  disabled in Grok's skills config; Grok does not inherit that state.
- Known and accepted gap: the four authored subagents are NOT available in Grok.
  Their absence is not a FAIL. A partial copy under `~/.grok/agents/` would be.

## 5. Shell and personal toggle

Only when the personal toggle was selected:

- Compare the live shell aliases/functions with `sources/shell/aliases.zsh`.
- Verify selected terminal/settings templates after placeholder substitution.

## 6. Final synthesis

- Compare installed state with selected `PROVISION.md` intent.
- List remaining FAIL items with exact remediation.
- List extras separately; do not delete them during a verification-only run.
- A final PASS requires concrete command/tool evidence and no skipped required
  check.
