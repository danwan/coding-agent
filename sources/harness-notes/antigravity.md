# Antigravity — translation notes

You are translating the canonical `sources/claude/` content into Antigravity's
format. Check your **own current docs** for exact paths — the below is durable.

## Where things go
- **Global instructions:** `sources/claude/CLAUDE.md` → your `GEMINI.md`.
- **Rules:** stage the files from `sources/claude/rules/` where you load shared
  rules (an Antigravity plugin such as `house-rules/rules/` under your CLI's
  plugins dir works). Reference them from `GEMINI.md` so they are always applied.
  Copy **all** rules — don't drop any.
- **Runbooks:** consult-on-demand references; place with your other docs.
- **Subagents / skills:** if your version supports subagents, translate
  `sources/claude/agents/*.md` (body verbatim, map frontmatter to your fields);
  otherwise skip. Skills come from the shared `~/.agents/skills/` hub.
- **MCP:** configure `context7` (remote URL + API-key header) in your MCP config.

## No direct equivalent — skip
Hooks (none here by design), Claude `settings.json` permission/sandbox/env blocks,
statusLine, Claude-marketplace-only plugins.
