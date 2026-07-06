# Codex — translation notes

You are translating the canonical `sources/claude/` content into Codex's format.
Check your **own current docs** for exact paths/keys — the below is the durable
mapping, not a schema you should copy verbatim.

## Where things go
- **Global instructions:** `sources/claude/CLAUDE.md` → your global `AGENTS.md`.
- **Rules:** the files in `sources/claude/rules/` are always-loaded guidance.
  Codex has no per-path rule mechanism; fold their intent into `AGENTS.md`
  (or an imported instruction file) so it is always in context. Copy **all** of
  them — do not silently drop any (a past translation lost a Golden Rule this way).
- **Runbooks:** `sources/claude/runbooks/` are consult-on-demand references;
  place them where you keep on-demand docs and link them from `AGENTS.md`.
- **Subagents:** `sources/claude/agents/*.md` → your TOML agent definitions.
  Keep the instruction **body** verbatim; map the frontmatter fields.
- **Skills:** placed in the shared `~/.agents/skills/` hub; link into your skills dir.

## Frontmatter → TOML mapping (map to your current keys, don't pin values)
| Claude frontmatter | Codex equivalent |
| --- | --- |
| `name`, `description` | same |
| `model: haiku\|sonnet\|opus` | your nearest model **tier** — resolve the current model id yourself, don't hardcode one |
| `effort: low\|medium\|high` | your reasoning-effort key |
| `tools:` allow-list | Codex tool access is session/sandbox-controlled, not per-agent — record intent in a comment |
| `maxTurns` | your turn-limit key if one exists, else note it has none |
| body (markdown) | the instruction string field (e.g. triple-quoted) |

## No direct equivalent — skip or degrade gracefully
Hooks (this setup has none by design), `settings.json` permission/sandbox/env
blocks, statusLine. Configure the analogous Codex setting if one exists; else skip.
