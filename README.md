# coding-agent

An intent-based, Claude-focused coding-agent setup. Public. Provisioned by
pasting a prompt into an agent — no install scripts, no hooks.

`PROVISION.md` declares *what* should be on a machine, *from where*, and
*why*, plus a one-line *verify* per item. It has no install commands on
purpose: the agent reads it and figures out how, using its own current
knowledge of tools and mechanisms at the time you run it.

## Layout

| Path | Purpose |
| --- | --- |
| `PROVISION.md` | Intent: what to install, from where, why, how to verify |
| `SETUP-PROMPT.md` | Paste-and-go master prompt (contains the raw URL to `PROVISION.md`) |
| `sources/` | Authored config + dotfiles the agent places on the machine |
| `docs/` | Design specs and plans behind this setup |

## Use it

1. Install Claude Code.
2. Paste the contents of `SETUP-PROMPT.md` into a new session — or just tell
   the agent to read the raw URL in that file and run it.
3. Answer the prompts about optional items/modules when asked.

## Secrets

Secrets are never stored in this repo — only their names and `op://`
references (1Password CLI). Values are resolved locally at provision time or
entered interactively.
