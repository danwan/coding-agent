# Windsurf — translation notes

You are translating the canonical `sources/claude/` content into Windsurf's
format. Check your **own current docs** for exact paths — the below is durable.

## The constraint that shapes everything here
Windsurf's only global instruction surface is
`~/.codeium/windsurf/memories/global_rules.md`, and it is capped at **6 000
characters**. There is **no global rules directory**. Everything else in this
repo's authored content is larger than that budget combined.

So Windsurf is the one harness that cannot receive the full rule set. Place
`sources/claude/CLAUDE.md` alone and check its size before writing: if CLAUDE.md
ever grows past ~6 000 characters, Windsurf silently truncates rather than
failing, and the tail of the Golden Rules disappears without a warning. `sync.sh`
refuses to write in that case instead of shipping a half file — keep that
behavior in any reimplementation.

## Where things go
- **Global instructions:** `sources/claude/CLAUDE.md` → `global_rules.md`, no
  frontmatter, always active.
- **Rules:** not globally possible. Per workspace, `.devin/rules/*.md`
  (preferred) or `.windsurf/rules/*.md` (legacy) take 12 000 characters each and
  support a `trigger:` frontmatter key (`always_on`, `glob`, `model_decision`,
  `manual`). Stage rules there per project when a project needs them.
- **Runbooks:** no place for them globally; reference by path from the rules.
- **Subagents:** no documented support for user-defined subagents. Skip.
- **Skills:** `SKILL.md` under `~/.codeium/windsurf/skills/<name>/`, or symlinks
  into the shared `~/.agents/skills/` hub. Auto-invocation is reported as
  unreliable — expect to name the skill explicitly.

## Hooks
`~/.codeium/windsurf/hooks.json` (user) merged with `.windsurf/hooks.json`
(workspace). Event names are snake_case and unlike Claude's: `pre_read_code`,
`pre_write_code`, `pre_run_command`, `pre_mcp_tool_use`, `pre_user_prompt` and
their `post_*` counterparts, plus `post_cascade_response` and
`post_setup_worktree`.

**Control flow is exit-code only** — there is no JSON response protocol and no
`permissionDecision`. The authored hook scripts emit Claude's response shape,
which Windsurf ignores entirely. Do not copy them across: rewrite the behavior
against exit codes (0 = proceed, 2 = block), or skip the hook here.
