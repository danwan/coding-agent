# Factory Droid — translation notes

You are translating the canonical `sources/claude/` content into Factory Droid's
format. Check your **own current docs** for exact paths — the below is durable.

## Where things go
- **Global instructions:** Droid looks for `AGENTS.md` in `~/.factory/`,
  `~/.agents/` and `~/.agent/`, and it also accepts the name `CLAUDE.md`. The
  shared hub copy at `~/.agents/AGENTS.md` therefore already reaches it; place
  `~/.factory/AGENTS.md` as well so the intent is explicit rather than implied.
  Documented budget: 80 000 characters on the initial load.
- **Rules:** there is **no rules directory**. Multiple files exist only through
  the AGENTS.md hierarchy, so the rules must be inlined into that one file if
  they are to apply globally — or left to project-level `.factory/AGENTS.md`.
- **Subagents:** "Custom Droids" in `~/.factory/droids/`, Markdown with YAML
  frontmatter (`name` matching `^[a-z0-9-_]+$`, `description`, `model`,
  `reasoningEffort`, `tools`, `mcpServers`). Translate `sources/claude/agents/*.md`
  bodies verbatim and map the frontmatter fields.
- **Skills:** `SKILL.md` under `~/.factory/skills/`, or symlinks into the shared
  `~/.agents/skills/` hub.
