# Cursor — translation notes

You are translating the canonical `sources/claude/` content into Cursor's
format. Check your **own current docs** for exact paths — the below is durable.

## Where things go
- **Rules:** `sources/claude/rules/*.md` → Cursor rule files (`.mdc` with a
  `description` + optional `globs` frontmatter). An always-applied rule (no
  `globs`) mirrors an always-loaded Claude rule; a path-scoped one uses `globs`.
  Copy **all** of them.
- **Global instructions:** fold `sources/claude/CLAUDE.md` into an always-applied
  rule (or your user-rules field) so it is always in context.
- **MCP:** configure `context7` (remote URL + API-key header) in Cursor's
  `mcp.json`. Add other remote MCP servers you use.
- **Skills / subagents:** if your Cursor version supports them, translate from
  `sources/claude/`; otherwise skip and note it.

## Stack-specific rules stay project-local
Do **not** install Convex/Vercel/Next/Modal rule files globally — per this repo's
own rule, stack skills/rules live inside each project, not in the global config.

## No direct equivalent — skip
Hooks (none here), Claude `settings.json` sandbox/permission/env blocks, statusLine.
