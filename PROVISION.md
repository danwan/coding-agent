# PROVISION — Intent (Claude Code)

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

## MCP servers
- context7  [default] — https://mcp.context7.com/mcp — why: current library docs — secret: CONTEXT7_API_KEY (op://Private/CONTEXT7_API_KEY/credential) — verify: server lists tools
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

## Skills — own (stored in this repo; the prompt PLACES them)  [default]
branch-cleanup · challenge · code-search · git-sync · grill-me · security-review · pr-workflow · stack-detection
verify: `/` shows each; skills load

## Skills — own, optional (stored, not default)  [optional]
- config-edit — why: path syntax reference for Claude Code settings/permissions/hooks
- convex-vercel-setup — why: standardize/audit Vercel+Convex+Modal deploy config (project-local preferred)
- convexcheck — why: report-only audit of a project's Convex+Vercel+Modal deploy footguns (project-local preferred)
- deploy — why: safe Modal/Convex deploy delegating to project deploy-script gates (project-local preferred)
- notion-safe-writes — why: guardrails against known Notion MCP write bugs before create/edit calls
- performance-review — why: automated Next.js+Convex+Modal performance checks (project-local preferred)
- pin-auth — why: scaffold PIN-based auth (Convex or lightweight HMAC variant) into a Next.js app
- review-routing — why: routing lookup to resolve which review/security tool is the default in a given case
verify: `/` shows each once placed; skills load

## Skills — remote meta (skills.sh)  [default]
- mcp-builder — anthropics/skills — verify: skills list shows it
- find-skills — vercel-labs/skills — verify: skills list shows it

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
(No hooks — by design.)

## System & Shell Environment  [default]
- **Shell Aliases:** Preconfigured aliases inside `.bashrc` or `.zshrc` (`l`, `la`, `ll`, `ls`, `grep`, `egrep`, `fgrep`, and `alert` notify-send) to ensure visual coherence and terminal efficiency.
- **SSH Tmux Auto-Load:** Shell configured to automatically launch or attach to a default tmux session when connected via SSH.
- **Tailscale SSH:** Tailscale installed and initialized with SSH enablement flag (`sudo tailscale up --ssh`) to allow secure passwordless access.

## Personal  [optional toggle]
- shell/aliases.zsh, shell/tmux.conf, wezterm/wezterm.lua → dotfiles
- settings.json (permissions, env, statusLine) + statusline.sh → Claude settings (permissions are personal; not applied unless chosen)

## Secrets
- CONTEXT7_API_KEY — op://Private/CONTEXT7_API_KEY/credential
- (REF_API_KEY, EXA_API_KEY are Cursor-only — not in the Claude default)
