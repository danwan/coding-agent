# coding-agent

An intent-based coding-agent setup. Public. Provisioned by pasting a prompt into
an agent — no install scripts. Authored content is stored **once**, in
Claude Code's format; the prompt is **harness-agnostic**, so Claude Code, Codex,
OpenCode, Antigravity or Cursor can each run it and translate the same source
into its own format.

`PROVISION.md` declares *what* should be on a machine, *from where*, and
*why*, plus a one-line *verify* per item. It has no install commands on
purpose: the agent reads it and figures out how, using its own current
knowledge of tools and mechanisms at the time you run it.

## Layout

| Path | Purpose |
| --- | --- |
| `PROVISION.md` | Intent: what to install, from where, why, how to verify |
| `SETUP-PROMPT.md` | Paste-and-go master prompt — detects the harness/OS, then installs + translates |
| `sources/claude/` | **Single source of truth**: authored CLAUDE.md, rules, runbooks, agents, settings |
| `sources/skills/` | Own skills (source of truth) |
| `sources/harness-notes/` | Per-harness translation notes — only what a non-Claude agent can't derive |
| `sources/shell/`, `sources/wezterm/` | Personal dotfiles (optional toggle) |
| `docs/` | Design specs, plans, and per-harness research (reference) |

## Use it

1. Install Claude Code.
2. Paste the contents of `SETUP-PROMPT.md` into a new session — or just tell
   the agent to read the raw URL in that file and run it.
3. Answer the prompts about optional items/modules when asked.

## Secrets

Secrets are never stored in this repo — only their names and `op://`
references (1Password CLI). Values are resolved locally at provision time or
entered interactively.
