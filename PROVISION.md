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
- context7  [default] — https://mcp.context7.com/mcp — why: current library docs — prefer the agent's OAuth/keychain flow; API-key fallback: CONTEXT7_API_KEY from op://APIKeys/context7/credential via the harness's shell wrapper, **never a literal in a config file** — verify: server lists tools and one library-resolution call succeeds
- playwright  [optional] — npx @playwright/mcp@latest — why: headless browser — verify: agent can screenshot a page
- google-developer-knowledge  [optional] — https://developerknowledge.googleapis.com/mcp — why: Google-platform docs — verify: server lists tools

## Plugins (Claude Code)
marketplaces: anthropics/claude-plugins-official (the only one — do not register
others unless a plugin below requires it)

**Selection rule: a plugin must provide a capability the model does not have.**
An external service, an index, a language server, a paid engine — something that
exists outside the model. Plugins that only inject prompt text (process
checklists, style guardrails, review personas written as sub-agents) do not
qualify: a current frontier model already does that, and their agent and skill
descriptions are charged to *every* session's context whether invoked or not.
Measure before adding: `claude plugin details <name>` prints the always-on token
cost. Treat anything above ~1k always-on tokens as needing a written
justification here.

- commit-commands  [default] — why: /commit, /commit-push-pr, /clean_gone — verify: /plugin lists it
- skill-creator  [default] — why: authoring plus evals/benchmarks for skills — verify: /plugin lists it
- coderabbit  [default] — why: external review engine, own CLI quota and
  subscription; the default reviewer — verify: `coderabbit --version` and /plugin lists it
- greptile  [default] — why: server-side repo index (a capability no local model
  has); needs GREPTILE_API_KEY (op://APIKeys/greptile/credential, resolved by the
  `claude()` shell wrapper — see `sources/shell/aliases.zsh`) — verify: /plugin lists it
- typescript-lsp / pyright-lsp  [optional] — why: real language servers; zero
  context cost — verify: /plugin lists it

### Evaluated and rejected (2026-07-31)
Recorded so the next audit does not re-litigate it. Measured with
`claude plugin details <name>`; "always-on" is charged to every session whether
the plugin is invoked or not.

| Plugin | Always-on | Why it went |
| --- | --- | --- |
| pr-review-toolkit | ~3.6k tok | Six agent descriptions full of `<example>` dialogue land in the tool schema every session. Prompt-only reviewers; collides three ways with `/code-review`, `/simplify` and coderabbit. |
| ponytail | ~1k tok + a SessionStart injection repeated on **every** SubagentStart | A style preference, not a capability. The per-subagent re-injection makes it the most expensive plugin under fan-out. |
| superpowers | ~0.7k tok + SessionStart injection | Fourteen process skills that duplicate built-ins (plan mode, `EnterWorktree`, the Agent tool) or restate what current models do unprompted. Its TDD and verification skills are the exact scaffolding the Opus 5 guide says to delete. |
| aikido | 0 (was disabled) | Would be a third security layer beside ggshield (local) and GitGuardian (server) plus an `npx` MCP process per session. |
| frontend-design | 0 (was disabled) | Covered by the built-in `dataviz` and `artifact-design` skills. |
| memsearch | 0 (not enabled) | Superseded by native auto-memory. Removed everywhere, not just disabled. |

### Considered and measured, not installed
All 276 plugins in the official marketplace were filtered against the selection
rule and against the stack this machine actually uses. Most are vendor
integrations for services not in use; the overlapping ones (context7, notion,
sentry, exa, github, gitkraken, playwright) are already configured as MCP
servers, and the code-search and security ones (serena, lumen, sourcegraph,
semgrep, sonarqube, claude-security) duplicate greptile, coderabbit and ggshield.

One genuine candidate survived that filter and was installed to measure:
**`convex`** — official, and its MCP server offers live deployment introspection
(schema, functions, logs, real queries), which is exactly the "capability the
model does not have" the rule asks for. Measured: **~3,332 always-on tokens**,
nearly the same as the pr-review-toolkit that was removed. The breakdown is the
decisive part: the MCP server and the three hooks cost nothing (tool schemas
resolve at runtime), while all 3.3k sit in 18 bundled skills — `auth`, `crons`,
`env`, `migrate`, `seed`, `test`, `domains` — the same vendor documentation this
audit had just deleted in its standalone form.

Taming it would mean 17 `skillOverrides` entries to keep the MCP and suppress
the rest: exactly the maintenance ballast this audit set out to remove. So it
was uninstalled. **If live Convex introspection is wanted, add the MCP server
alone, project-local** — per the stack-skills rule below, not as a global plugin.

The kept six all clear the bar for a different reason each: coderabbit and
greptile are external services, the two LSPs are real language servers costing
nothing, skill-creator provides evals no prompt replaces, commit-commands is
three cheap slash commands. Nothing was installed to fill a gap, because the
audit found none: everything a candidate plugin would have added is either a
built-in (`/code-review`, `/simplify`, plan mode, worktrees, auto-memory,
Monitor, `/usage`) or a capability of the model.

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
branch-cleanup · challenge · git-sync · grill-me · security-review · pr-workflow · stack-detection
verify: `/` shows each; skills load

- chrome-ui-explorer  [default, Claude Code only] — why: exploratory full-app UI
  testing through the user's real Chrome via the Claude-in-Chrome extension.
  Placement exception: it goes into `~/.claude/skills/` as a real directory, NOT
  into the `~/.agents/skills/` hub, because no other harness drives that
  extension — verify: `/` shows it and the extension answers one `tabs_context` call

## Skills — own, optional (stored, not default)  [optional]
- config-edit — Claude Code only; why: path syntax reference for its settings/permissions/hooks
- convexcheck — why: report-only audit of a project's Convex+Vercel+Modal deploy footguns (project-local preferred)
- deploy — why: safe Modal/Convex deploy delegating to project deploy-script gates (project-local preferred)
- notion-safe-writes — Claude/raw-Notion-MCP only; do not install for Codex's app connector
- performance-review — why: automated Next.js+Convex+Modal performance checks (project-local preferred)
- pin-auth — why: scaffold PIN-based auth (Convex or lightweight HMAC variant) into a Next.js app
- review-routing — Claude Code only; why: routing lookup across its review/security plugins
verify: `/` shows each once placed; skills load

## Skills — remote meta (skills.sh)  [optional]
- mcp-builder — anthropics/skills — why: Anthropic's own process for MCP-server
  quality; keep `off` in skillOverrides until an MCP server is actually being built

## Skills — remote, globally installed (documented only — NOT stored in this repo)  [optional]
Remote skills live only as installs via `npx skills add -g` (canonical copy in
`~/.agents/skills/`, symlinked into each harness). Re-install from their
registries; this repo documents the intent, never their content.

**Selection rule: do not install vendor documentation as a skill.** A skill that
restates a library's public docs is stale the day it is written, duplicates what
Context7 fetches live, and several such skills tell the agent to "fetch the
latest documentation" in their own body. Install a remote skill only when it
carries a *procedure* (an ordered, failure-avoiding recipe) or setup knowledge
that is not in any public doc. Currently:
- convex-best-practices · convex-functions · convex-security-audit ·
  convex-security-check — waynesutton/convexskills; why: the Zen-of-Convex
  design stance and the security checklists, not the API reference
- vercel-cli-with-tokens — vercel-labs/agent-skills; why: token auth without
  leaking values into shell history, team scoping, env-var handling
- vercel-optimize — vercel-labs/agent-skills; why: metrics-first gating plus
  scripts; keep `off` until a real Vercel cost question exists
- next-cache-components-adoption · next-cache-components-optimizer — vercel/next.js;
  why: a test-driven migration loop; keep `off` until such a migration is due
- claude-api — anthropics/skills; why: model ids and pricing drift faster than
  any model's training data
- web-design-guidelines — vercel-labs/agent-skills; why: a stub that fetches the
  guidelines live, so it cannot go stale; keep `off` until doing design work
- computer-use · orca-cli · orchestration — stablyai/orca; why: stubs whose
  reference comes from the `orca` binary; keep `off` unless Orca is in use
These named global skills are deliberate cross-project exceptions. Everything
else under Module: webservice remains project-local.

## Module: webservice  [ask]  — mostly project-local
- optional global plugins: typescript-lsp
- stack SKILLS are PROJECT-LOCAL — inside each project: `npx skills add <source>` WITHOUT -g, commit .agents/ + skills-lock.json:
  vercel-labs/agent-skills · vercel/next.js · waynesutton/convexskills · (Modal: uv is in baseline)

## Keeping harnesses in sync  [default]
`./sync.sh` places the authored content into every installed agent, and
`./sync-agents.py` translates the four subagent definitions into each
harness's own container (Codex wants TOML with the prompt inline; the rest
want markdown with differently-named frontmatter keys). Model names are not
translated — an existing per-harness model choice is preserved, otherwise the
field is omitted so the agent inherits the session model. No argument
= dry run, `--apply` = write, absent harnesses are skipped, and it is idempotent.
Run it after any change under `sources/`. verify: a second `./sync.sh` reports
`zu schreiben: 0`. Per-harness format limits are documented in
`sources/harness-notes/README.md` — Windsurf's 6 KB cap and Cursor's `.mdc`
frontmatter requirement in particular mean "identical" is not achievable
everywhere, and the script fails loud rather than truncating.

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
No API key value belongs in any config file on disk, in any harness. The target
state is that every key is resolved from 1Password at process start. Where a
harness supports config-time substitution, it references an env var that a shell
wrapper fills from `op read` — never a literal. Vault is `APIKeys`; there is no
`Private` vault on this machine.

- CONTEXT7_API_KEY — op://APIKeys/context7/credential, exported by the
  `opencode()` wrapper in `sources/shell/aliases.zsh`; `opencode.json` references
  it as `{env:CONTEXT7_API_KEY}`. ⚠️ opencode substitutes a **missing** variable
  with the empty string instead of erroring, so the wrapper checks explicitly and
  says so — otherwise an unauthenticated Context7 looks like a working one.
  For Claude Code, Context7 uses its own OAuth/keychain flow and needs no key.
  Codex holds the same key; its secure form is the HTTP transport with
  `env_http_headers` (header name → env var name) instead of a stdio server with
  a literal `[mcp_servers.context7.env]` block:
  ```toml
  [mcp_servers.context7]
  url = "https://mcp.context7.com/mcp"
  env_http_headers = { CONTEXT7_API_KEY = "CONTEXT7_API_KEY" }
  ```
  filled by the `codex()` wrapper. Do not flip either config before the
  1Password item exists — both harnesses fail *quietly* without the key.
- GREPTILE_API_KEY — op://APIKeys/greptile/credential (resolved per-start by the `claude()` wrapper)
- OPENROUTER_KEY — optional environment alternative; prefer `llm keys set openrouter` so the value stays in the CLI key store (see `sources/claude/runbooks/llm-cli-openrouter.md`)
- OP_SERVICE_ACCOUNT_TOKEN — macOS Keychain item `op-service-account` (basis for all `op run`/`op read`). It is **read-only** on the `APIKeys` vault: creating or updating an item fails with `(101) You do not have permission`. New secrets have to be added interactively by the user; an agent can read them but never write them.

Audit: no config file under any harness should contain a literal key.
`grep -rEl '(sk-|ctx7sk-|Bearer [A-Za-z0-9]{20})' ~/.claude ~/.codex ~/.config/opencode ~/.cursor ~/.gemini ~/.factory --include='*.json' --include='*.toml' 2>/dev/null`
should print nothing.
- (REF_API_KEY, EXA_API_KEY are Cursor-only — not in the Claude default)
