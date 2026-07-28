# PROVISION — Intent (all supported coding agents)

What this machine should have, from where, why, and how to verify. The master
prompt (SETUP-PROMPT.md) reads this and configures the agent using its current
knowledge — no install commands here. Secret NAMES + op:// refs only, never
values. Tags: [default] on every machine · [optional] ask · [module:x] grouped.

## CLI tools  [default]
The **binary name alone is not enough** to resolve a tool across macOS / Linux /
Windows — several collide or are packaged under a different name. Each row gives
the invoked binary, the canonical source (so you install the RIGHT thing), and a
resolve note. Pick the package for THIS OS's package manager; the homepage/repo
is the tie-breaker when a name is ambiguous.
verify (all): the binary's `--version` (or `--help`) succeeds.

| Invoke | Canonical source | Resolve note (cross-OS) |
| --- | --- | --- |
| `git` | git-scm.com | ships or via package manager |
| `gh` | GitHub CLI — cli.github.com (`gh`) | — |
| `rg` | ripgrep — github.com/BurntSushi/ripgrep | package is **`ripgrep`**, binary is `rg` |
| `fd` | fd — github.com/sharkdp/fd | Debian/Ubuntu package is **`fd-find`** and installs the binary as **`fdfind`** (the name `fd` is taken) → symlink/alias to `fd`. brew/Arch/scoop/winget: `fd` |
| `sg` | ast-grep — ast-grep.github.io | install as **`ast-grep`** (npm `@ast-grep/cli`, cargo `ast-grep`, brew `ast-grep`). ⚠️ the `sg` binary **collides with util-linux `sg`** on Linux — prefer invoking `ast-grep`, add the `sg` alias only if free |
| `jq` | jqlang.github.io/jq (`jq`) | — |
| `tree` | `tree` in every package manager | — |
| `tmux` | `tmux` in every package manager | — |
| `tailscale` | tailscale.com | VPN client and secure network overlay. Enables secure SSH access via Tailscale SSH. |
| `micro` | micro editor — github.com/zyedidia/micro | package/binary **`micro`** (brew/apt/snap/scoop/winget id `zyedidia.micro`). ⚠️ collides with **go-micro** (micro.dev, github.com/micro/micro) — a different CLI also named `micro`; install the editor, not the microservices toolkit |
| `uv` | Astral — github.com/astral-sh/uv (`uv`) | astral.sh installer or brew/pipx/winget `uv` |
| `fnm` | Fast Node Manager — github.com/Schniz/fnm | package/binary `fnm` (winget id `Schniz.fnm`) |
| `bun` | Bun — bun.sh (`bun`) | bun.sh installer or brew `oven-sh/bun/bun` |
| `op` | 1Password CLI — developer.1password.com/docs/cli | package is **`1password-cli`** (brew cask `1password-cli`; Linux via 1Password's own apt/rpm repo), binary is `op` — not in default distro repos |
| `qmd` | npm **`@tobilu/qmd`** | install from npm ONLY — **never** a GitHub source of the same name |
| `skills` | skills.sh — run via **`npx skills`** | no global binary needed |
| `llm` | Simon Willison — llm.datasette.io, with `llm-openrouter` | install the Python CLI with the OpenRouter plugin via `uv`; why: second opinions from multiple providers through one OpenRouter account. Configure interactively with `llm keys set openrouter`, then choose a current model and alias it per `sources/claude/runbooks/llm-cli-openrouter.md`. ⚠️ unrelated packages also use the name `llm`. verify: `llm --version`, `llm models -q openrouter`, and one prompt through the configured alias succeed |
| `agent-browser` | Vercel Labs — github.com/vercel-labs/agent-browser | browser automation CLI used for usability and repeatable headless UI tests. Install the browser runtime after the CLI. This is separate from Codex's in-app Browser and Chrome plugins. verify: `agent-browser doctor --offline --quick` passes and opening `https://example.com` returns the title |
| `ggshield` | GitGuardian CLI — github.com/GitGuardian/ggshield | brew/pipx `ggshield`. Post-install (per user, interactive): `ggshield auth login` (token → OS keyring), then verify `ggshield quota` is greater than zero before installing hooks. Install the global `pre-push` target and the detected agent target (`claude-code` for Claude Code, `codex` for Codex) only while scanning quota is available; otherwise the pre-push hook blocks normal pushes and the agent hook can only fail open noisily. Husky repos need their own `.husky/pre-push` with `ggshield secret scan pre-push "$@"` (local hooksPath shadows global). Do not dismiss a failed `ggshield api-status` as sandbox noise without verifying keyring auth. Why: enforces `rules/secrets-in-git.md` — see its Enforcement section. verify: `ggshield api-status` is healthy, `ggshield quota` is positive, and a benign scan succeeds |

## MCP servers
- context7  [default] — https://mcp.context7.com/mcp — why: current library docs — prefer the agent's OAuth/keychain flow; API-key fallback: CONTEXT7_API_KEY (op://Private/CONTEXT7_API_KEY/credential), never a literal committed header — verify: server lists tools and one library-resolution call succeeds
- playwright  [optional] — npx @playwright/mcp@latest — why: headless browser — verify: agent can screenshot a page
- google-developer-knowledge  [module:google] — https://developerknowledge.googleapis.com/mcp — verify: server lists tools

## Plugins (Claude Code)
marketplaces: anthropics/claude-plugins-official, DietrichGebert/ponytail, zilliztech/memsearch
- superpowers  [default] — why: lifecycle process skills — verify: /plugin lists it
- skill-creator  [default] — why: author new skills — verify: /plugin lists it
- commit-commands  [default] — why: /commit, /commit-push-pr, /clean_gone — verify: /plugin lists it
- pr-review-toolkit  [default] — why: multi-agent PR review — verify: /plugin lists it
- ponytail  [default] — why: simplicity guardrail — verify: /plugin lists it
- memsearch  [optional] — why: cross-session memory recall (needs Python memsearch[onnx]) — verify: /plugin lists it
- coderabbit / frontend-design / typescript-lsp / pyright-lsp  [optional]
- greptile  [optional] — why: Greptile code-review MCP; needs GREPTILE_API_KEY
  (op://APIKeys/greptile/credential, resolved by the `claude()` shell wrapper —
  see `sources/shell/aliases.zsh`) — verify: /plugin lists it

## Plugins (Codex)
- Browser + Chrome  [default in the desktop app] — Browser controls the
  app-owned browser; Chrome controls the user's existing Chrome profile.
  Browser is app-only. verify: each selected surface can open `https://example.com`
- GitHub · Gmail · Google Calendar · Google Drive · Notion · Vercel
  [default on this setup] — use the OpenAI-curated app plugins and their
  authenticated app connectors. Do not add a second raw MCP leg unless it
  provides a capability the app connector lacks. verify: one read-only profile,
  list, or lookup call succeeds for each configured service
- The Vercel plugin already supplies the `agent-browser` and
  `agent-browser-verify` skills. Do not install a second standalone copy of the
  same skill; the `agent-browser` CLI above is still required. Keep only these
  two Vercel plugin skills globally enabled on this setup; the connector tools
  remain available and specialized guidance can come from current docs or
  project-local skills without overflowing Codex's skill-description budget.

## Skills — own (stored in this repo; the prompt PLACES them)  [default]
branch-cleanup · challenge · code-search · git-sync · grill-me · security-review · pr-workflow · stack-detection
verify: `/` shows each; skills load

## Skills — own, optional (stored, not default)  [optional]
- config-edit — Claude Code only; why: path syntax reference for its settings/permissions/hooks
- convexcheck — why: report-only audit of a project's Convex+Vercel+Modal deploy footguns (project-local preferred)
- deploy — why: safe Modal/Convex deploy delegating to project deploy-script gates (project-local preferred)
- notion-safe-writes — Claude/raw-Notion-MCP only; do not install for Codex's app connector
- performance-review — why: automated Next.js+Convex+Modal performance checks (project-local preferred)
- pin-auth — why: scaffold PIN-based auth (Convex or lightweight HMAC variant) into a Next.js app
- review-routing — Claude Code only; why: routing lookup across its review/security plugins
verify: `/` shows each once placed; skills load

Stored but intentionally not provisioned: `convex-vercel-setup` still references
machine-specific paths and missing central assets from the retired setup repo.
Keep it disabled until it is rewritten around portable, repo-local assets.

## Skills — remote meta (skills.sh)  [default]
- mcp-builder — anthropics/skills — verify: skills list shows it
- find-skills — vercel-labs/skills — verify: skills list shows it

## Skills — remote, globally installed (documented only — NOT stored in this repo)  [optional]
Remote skills live only as installs via `npx skills add -g` (canonical copy in
`~/.agents/skills/`, symlinked into each harness). Re-install from their
registries; this repo documents the intent, never their content. Currently:
- convex-* (best-practices, cron-jobs, file-storage, functions, http-actions,
  migrations, realtime, schema-validator, security-audit, security-check) — waynesutton/convexskills
- avoid-feature-creep — waynesutton/convexskills
- vercel-cli-with-tokens — vercel-labs/agent-skills
- webapp-testing · claude-api — anthropics/skills
- vitest — antfu/skills
- google-agents-cli-* — installed by `uvx google-agents-cli setup` (see Module: google)
These named global skills are deliberate cross-project exceptions. Everything
else under Module: webservice remains project-local.

## Module: google  [ask]
- google skills + agents-cli — `uvx google-agents-cli setup` (installs google-agents-cli-* skills globally; CLI-tied) — verify: agents-cli info
- google-developer-knowledge MCP (see MCP section)

## Module: webservice  [ask]  — mostly project-local
- optional global plugins: frontend-design, typescript-lsp
- stack SKILLS are PROJECT-LOCAL — inside each project: `npx skills add <source>` WITHOUT -g, commit .agents/ + skills-lock.json:
  vercel-labs/agent-skills · vercel/next.js · waynesutton/convexskills · (Modal: uv is in baseline)

## Authored config (placed from this repo)  [default]
Stored ONCE, in Claude Code's format, under `sources/claude/` (single source of
truth). A non-Claude agent translates these into its own format at provision time
(see `sources/harness-notes/<harness>.md` for the format mapping).
- `sources/claude/CLAUDE.md` → the agent's global instruction file
- `sources/claude/rules/` → where this agent reads global rules (copy ALL)
- `sources/claude/runbooks/` → referenced on demand (not auto-loaded)
- `sources/claude/agents/` → subagent definitions
- `sources/claude/hooks/` → lifecycle hook logic plus Claude Code's native
  implementation. Non-Claude agents must translate both the wiring and the
  hook input/output protocol; do not blindly reuse Claude JSON fields. Codex
  currently supports equivalents in `~/.codex/hooks.json` (details in
  `sources/harness-notes/codex.md`).

## System & Shell Environment  [default]
- **Shell Aliases & Functions:** The canonical alias/function block for `~/.zshrc` is `sources/shell/aliases.zsh` (agent aliases `c`/`cc`/`co`/`oc`, git helpers, 1Password keychain token + `claude()` Greptile-key wrapper). NOTE: `op` is the 1Password CLI, never an alias.
- **SSH Tmux Auto-Load:** Shell configured to automatically launch or attach to a default tmux session when connected via SSH.
- **Tailscale SSH:** Tailscale installed and initialized with SSH enablement flag (`sudo tailscale up --ssh`) to allow secure passwordless access.

## Personal  [optional toggle]
- shell/aliases.zsh, shell/tmux.conf, wezterm/wezterm.lua → dotfiles
- settings.json (permissions, env, statusLine) + statusline.sh → Claude settings (permissions are personal; not applied unless chosen)

## Secrets
- CONTEXT7_API_KEY — op://Private/CONTEXT7_API_KEY/credential
- GREPTILE_API_KEY — op://APIKeys/greptile/credential (resolved per-start by the `claude()` wrapper)
- OPENROUTER_KEY — optional environment alternative; prefer `llm keys set openrouter` so the value stays in the CLI key store (see `sources/claude/runbooks/llm-cli-openrouter.md`)
- OP_SERVICE_ACCOUNT_TOKEN — macOS Keychain item `op-service-account` (basis for all `op run`/`op read`)
- (REF_API_KEY, EXA_API_KEY are Cursor-only — not in the Claude default)
