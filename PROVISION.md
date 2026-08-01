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
| `micro` | micro editor — github.com/zyedidia/micro | package/binary **`micro`** (brew/apt/snap/scoop/winget id `zyedidia.micro`). ⚠️ collides with **go-micro** (micro.dev, github.com/micro/micro) — a different CLI also named `micro`; install the editor, not the microservices toolkit |
| `uv` | Astral — github.com/astral-sh/uv (`uv`) | astral.sh installer or brew/pipx/winget `uv` |
| `fnm` | Fast Node Manager — github.com/Schniz/fnm | package/binary `fnm` (winget id `Schniz.fnm`) |
| `bun` | Bun — bun.sh (`bun`) | bun.sh installer or brew `oven-sh/bun/bun` |
| `op` | 1Password CLI — developer.1password.com/docs/cli | package is **`1password-cli`** (brew cask `1password-cli`; Linux via 1Password's own apt/rpm repo), binary is `op` — not in default distro repos |
| `qmd` | npm **`@tobilu/qmd`** | install from npm ONLY — **never** a GitHub source of the same name |
| `skills` | skills.sh — run via **`npx skills`** | no global binary needed |
| `agent-browser` | Vercel Labs — github.com/vercel-labs/agent-browser | browser automation CLI used for usability and repeatable headless UI tests. Install the browser runtime after the CLI. This is separate from Codex's in-app Browser and Chrome plugins. verify: `agent-browser doctor --offline --quick` passes and opening `https://example.com` returns the title |
| `ggshield` | GitGuardian CLI — github.com/GitGuardian/ggshield | brew/pipx `ggshield`. **Currently installed but not active** (state as of 2026-08-01): no token is readable, so `api-status` and `quota` both fail, and no global `core.hooksPath` is set — the hooks were retired 2026-07-31 when quota hit zero. That is the intended state, not a defect: secret scanning currently runs server-side via GitGuardian and in review via CodeRabbit. To reactivate: `ggshield auth login` (interactive, token → OS keyring), confirm `ggshield quota` is greater than zero, and only then install the global `pre-push` target plus the detected agent target (`claude-code` / `codex`). Never install those hooks without positive quota — the pre-push hook then blocks normal pushes and the agent hook can only fail open noisily. Husky repos need their own `.husky/pre-push` with `ggshield secret scan pre-push "$@"` (local hooksPath shadows global). Note the keyring is not readable from inside the agent sandbox, so a failed `api-status` there is not by itself proof of missing auth. verify: the binary runs (`ggshield --version`). Auth, quota and hooks are verified **only** when reactivation was selected |

## MCP servers
Configured per harness. **One leg per service**: where a harness already reaches
a service through an authenticated account connector or a plugin, do not add a
second raw MCP leg for it — the duplicate is unauthenticated or redundant, and
both legs' tool schemas are charged to every session.

- context7  [default, all harnesses] — https://mcp.context7.com/mcp — why: current library docs — key is CONTEXT7_API_KEY from op://APIKeys/context7/credential, injected by the harness's shell wrapper, **never a literal in a config file** — verify: server lists tools and one library-resolution call succeeds
- google-developer-knowledge  [optional] — https://developerknowledge.googleapis.com/mcp — why: Google-platform docs — verify: server lists tools
- playwright  [optional, OpenCode only] — npx @playwright/mcp@latest — why: headless browser for the one harness with no browser plugin; Claude and Codex use their own browser surfaces plus the `agent-browser` CLI — verify: agent can screenshot a page
- GitKraken  [optional, Codex] — why: git/PR operations beyond the `gh` CLI — verify: one read-only repo lookup succeeds
- greptile  [optional, Codex] — why: the same server-side repo index the Claude plugin provides, for the harness that has no such plugin; needs GREPTILE_API_KEY — verify: server lists tools
- computer-use  [optional, Codex] — why: desktop control, tied to the Orca toolchain — verify: server lists tools

**App-owned, not provisioned by this repo** — do not add, remove, or "fix" these;
the app writes them and will rewrite them again:
- `node_repl` — injected by the Codex desktop app into both its own and Claude's
  MCP config; it backs the in-app Browser plugin.
- The claude.ai account connectors (Notion, Gmail, Calendar, Drive, Exa, Sentry,
  n8n, …) and the OpenAI-curated Codex app plugins. They are bound to the signed-in
  account, have no portable standalone form, and are configured in the app rather
  than in a file this repo can own. Their permissions do appear in the personal
  `settings.json` template.

Grok configures MCP in `~/.grok/config.toml`, but also inherits Claude's servers
from `~/.claude.json` through its compat scanning — so a raw leg added for Claude
shows up there too. See `sources/harness-notes/grok.md`.

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
- greptile  [optional, installed but disabled] — why: server-side repo index (a
  capability no local model has); needs GREPTILE_API_KEY
  (op://APIKeys/greptile/credential, resolved by the `claude()` shell wrapper —
  see `sources/shell/aliases.zsh`) — verify: /plugin lists it
- typescript-lsp / pyright-lsp  [optional, installed but disabled] — why: real
  language servers; zero context cost — verify: /plugin lists it

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
| frontend-design | 0 (was disabled) | Covered by the built-in `dataviz` and `artifact-design` skills. Uninstalled 2026-08-01 — it had been left installed-but-disabled, which made this table read as done when it was not. |
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
- OpenAI-curated app connectors (GitHub, Gmail, Google Calendar, Google Drive,
  Notion, Vercel) — **none of them is installed** (verified 2026-08-01). This
  section previously described them as the default on this setup, including a
  claim that the Vercel plugin supplies the `agent-browser` skills. It does not,
  because it is not installed; the `agent-browser` CLI and the separately
  installed remote skill are what actually provide that capability. Do not
  re-add that claim without checking `codex plugin list` first.
  If a connector IS installed later: prefer it over a raw MCP leg for the same
  service, and keep its bundled skills trimmed with `[[skills.config]]` so they
  do not overflow Codex's skill-description budget. verify: one read-only
  profile, list, or lookup call succeeds per configured service.
- Notion in Codex therefore runs over the **raw MCP leg**, not a connector — it
  is the only access path there, and removing it would cut Notion off entirely.
- Claude-marketplace plugins in Codex [default on this setup]: `coderabbit`,
  `commit-commands`, `skill-creator`, `typescript-lsp`, `pyright-lsp` — installed
  and enabled. Codex registers the `claude-plugins-official` marketplace and runs
  these natively, so the same selection rule applies as for Claude Code. That is
  the complete list; anything else found installed is a prune candidate. (`linear`
  was installed-but-disabled and removed 2026-08-01 — Linear is not in use.)
  verify: `codex plugin list` shows exactly these five as installed/enabled.

## Skills — own (stored in this repo; the prompt PLACES them)  [default]
branch-cleanup · git-sync · stack-detection
verify: `/` shows each; skills load

## Skills — own, optional (stored, not default)  [optional]
- config-edit — Claude Code only; why: path syntax reference for its settings/permissions/hooks
- convexcheck — why: report-only audit of a project's Convex+Vercel+Modal deploy footguns (currently `off` in skillOverrides)
- deploy — why: safe Modal/Convex deploy delegating to project deploy-script gates (project-local preferred)
- notion-safe-writes — Claude/raw-Notion-MCP only; do not install for Codex's app connector
- pin-auth — why: scaffold PIN-based auth (Convex or lightweight HMAC variant) into a Next.js app (currently `off` in skillOverrides)
- review-routing — Claude Code only; why: routing lookup across its review/security plugins
verify: `/` shows each once placed; skills load

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
- agent-browser — **vercel-labs/agent-browser** (its own repo, not
  `agent-skills` — that was recorded wrongly until 2026-08-01); why: drives the
  `agent-browser` CLI (see CLI tools above) — procedure, not vendor docs
- skill-development — anthropics/claude-code; why: structure/progressive-disclosure
  guidance when authoring skills for this repo
- vercel-cli-with-tokens — vercel-labs/agent-skills; why: token auth without
  leaking values into shell history, team scoping, env-var handling
- vercel-optimize — vercel-labs/agent-skills; why: metrics-first gating plus
  scripts; keep `off` until a real Vercel cost question exists
- next-cache-components-adoption · next-cache-components-optimizer — vercel/next.js;
  why: a test-driven migration loop; keep `off` until such a migration is due
- computer-use · orca-cli · orchestration — stablyai/orca; why: stubs whose
  reference comes from the `orca` binary; keep `off` unless Orca is in use
These named global skills are deliberate cross-project exceptions. Everything
else under Module: webservice remains project-local.

**Convex skills are NOT among them.** waynesutton/convexskills is installed
per-project (see Module: webservice below), never with `-g`. This section
previously claimed four of them — convex-best-practices, convex-functions,
convex-security-audit, convex-security-check — as globally installed; audited
2026-07-31, none was present in `~/.agents/skills/`, in any harness, or in
`.skill-lock.json`. The entry documented an intent that had never been carried
out and that contradicted the project-local rule anyway. Do not re-add it: a
list that asserts installed state without it being true reads as verified
coverage when there is none.

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
`sources/harness-notes/README.md` — Codex's `project_doc_max_bytes` in particular
means "identical" is not achievable everywhere, and the script fails loud rather
than truncating.

**Grok is deliberately not placed into.** It reads `~/.claude/` directly, so a
copy under `~/.grok/rules/` would load every rule twice per session; `sync.sh`
reports it as inherited and warns if that directory is not empty. The trade-off
is that Grok does not get the four subagents — see `sources/harness-notes/grok.md`.

Supported harnesses are Claude Code, Codex, Grok, OpenCode and Antigravity.
Cursor and Factory Droid were removed from scope 2026-08-01 (both were trials);
Windsurf never was. See `sources/harness-notes/README.md` for the reasoning.

## Authored config (placed from this repo)  [default]
Stored ONCE, in Claude Code's format, under `sources/claude/` (single source of
truth). A non-Claude agent translates these into its own format at provision time
(see `sources/harness-notes/<harness>.md` for the format mapping).
- `sources/claude/CLAUDE.md` → the agent's global instruction file
- `sources/claude/rules/` → where this agent reads global rules (copy ALL)
- `sources/claude/agents/` → subagent definitions
- `sources/claude/templates/` → `~/.agents/templates/` — ADR and feature-spec
  templates, harness-neutral, one shared path. Nothing generates project docs
  automatically; `search-discipline.md` points at this path for when you write one.

There are no repo-authored security or deploy lifecycle hooks and no runbooks
anymore: those hooks were retired 2026-07-31 (ggshield quota at zero made them
fail-open noise; the backend-deploy check lives on as the `deploy-safety.md`
rule), and the runbook content was either folded into the rules or retired with
its feature. The only global lifecycle hooks retained in Claude Code and Codex
are the external Orca integration hooks under `~/.orca/agent-hooks/`; Orca owns
and manages them.

## System & Shell Environment  [default]
- **Shell Aliases & Functions:** The canonical alias/function block for `~/.zshrc` is `sources/shell/aliases.zsh` (agent aliases `c`/`cc`/`co`/`oc`, git helpers, 1Password keychain token, `codex()` Context7-key wrapper, and `claude()` Greptile-key wrapper). NOTE: `op` is the 1Password CLI, never an alias.

## Personal  [optional toggle]
- shell/aliases.zsh, wezterm/wezterm.lua → dotfiles
- settings.json (permissions, env, statusLine) + statusline.sh → Claude settings (permissions are personal; not applied unless chosen)

## Secrets
No API key value belongs in any config file on disk, in any harness. The target
state is that every key is resolved from 1Password at process start. Where a
harness supports config-time substitution, it references an env var that a shell
wrapper fills from `op read` — never a literal. Vault is `APIKeys`; there is no
`Private` vault on this machine.

- CONTEXT7_API_KEY — op://APIKeys/context7/credential, exported at process
  start by the `codex()`, `claude()`, and `opencode()` wrappers in
  `sources/shell/aliases.zsh`; their configs reference only the environment
  variable name. Each wrapper hard-fails when the item is missing so an
  unauthenticated Context7 cannot look like a working one. Claude Code expands
  `${CONTEXT7_API_KEY}` in its HTTP header. Codex uses HTTP transport with
  `env_http_headers` (header name → env var name) instead of a stdio server with
  a literal `[mcp_servers.context7.env]` block:
  ```toml
  [mcp_servers.context7]
  url = "https://mcp.context7.com/mcp"
  env_http_headers = { CONTEXT7_API_KEY = "CONTEXT7_API_KEY" }
  ```
  filled by the `codex()` wrapper. No literal Context7 key belongs in
  `~/.claude.json`, `~/.codex/config.toml`, or any other config file.
- GREPTILE_API_KEY — op://APIKeys/greptile/credential (resolved per-start by the `claude()` wrapper)
- OP_SERVICE_ACCOUNT_TOKEN — macOS Keychain item `op-service-account` (basis for all `op run`/`op read`). It is **read-only** on the `APIKeys` vault: creating or updating an item fails with `(101) You do not have permission`. New secrets have to be added interactively by the user; an agent can read them but never write them.

Audit: no *config* file of any supported harness may contain a literal key. Scan
the config files by name — not the whole home directories. Recursing over
`~/.claude` or `~/.codex` sweeps in session transcripts, model caches and bundled
plugin fixtures, which match the pattern constantly and drown the real finding:

```sh
grep -lE '(\b(sk|ctx7sk)-[A-Za-z0-9_-]{16,}|Bearer [A-Za-z0-9]{20})' \
  ~/.claude.json ~/.claude/settings.json ~/.codex/config.toml \
  ~/.config/opencode/opencode.json ~/.grok/config.toml \
  ~/.gemini/settings.json 2>/dev/null
```

should print nothing. Two details the earlier version got wrong, both worth
keeping: `~/.claude.json` is a *file* next to the directory, so a
directory-recursive scan never looked at the place Claude's MCP servers actually
live; and a bare `sk-` with no word boundary or length floor matches ordinary
identifiers — `task-master-ai` contains it, and one permanent false positive is
enough to make everyone stop reading the output.
