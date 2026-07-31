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
- **Runbooks:** consult-on-demand; place with your other docs, not in AGENTS.md.
- **Subagents:** "Custom Droids" in `~/.factory/droids/`, Markdown with YAML
  frontmatter (`name` matching `^[a-z0-9-_]+$`, `description`, `model`,
  `reasoningEffort`, `tools`, `mcpServers`). Translate `sources/claude/agents/*.md`
  bodies verbatim and map the frontmatter fields.
- **Skills:** `SKILL.md` under `~/.factory/skills/`, or symlinks into the shared
  `~/.agents/skills/` hub.

## Hooks
Droid's hook contract is very close to Claude Code's: same event names
(PreToolUse, PostToolUse, UserPromptSubmit, Notification, Stop, SubagentStop,
PreCompact, SessionStart, SessionEnd), stdin JSON with the same field names, and
the same response shape including `hookSpecificOutput.permissionDecision`. The
authored hook scripts are therefore portable here with little change.

**But the location differs:** the docs put hooks in `~/.factory/hooks.json`, not
in `settings.json`. A `hooks` key inside `settings.json` may be a legacy layout —
verify which one this Droid version actually reads before assuming your hooks
are live. A hook wired into the wrong file fails silently, which is
indistinguishable from a hook that ran and found nothing.
