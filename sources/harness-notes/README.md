# Harness notes

`sources/claude/` is the **single source of truth** for all authored content
(instructions, rules, runbooks, subagents) — written in Claude Code's format.
`sources/skills/` is the source of truth for own skills.

A non-Claude harness (Codex, OpenCode, Antigravity, Cursor, …) does **not** get
its own pre-translated copy in this repo — that only drifts. Instead, the setup
prompt (`SETUP-PROMPT.md`) has the target agent **translate the canonical files
into its own format at provision time**, after checking its own current docs for
where things live and how they load.

These notes carry only the small amount a target agent **cannot derive** from
`sources/claude/` plus its own documentation: the format mapping and the Claude
features that have no equivalent (skip them). They are deliberately
**principle-based, not version-pinned** — no exact model names, no schema dumps
(those change and would mislead). When a note and the harness's current docs
disagree, the current docs win.

| If you are… | Read | Config lives (verify against your own docs) |
| --- | --- | --- |
| Claude Code | nothing extra — `sources/claude/` is native | `~/.claude/` |
| Codex | [`codex.md`](codex.md) | `~/.codex/` |
| OpenCode | [`opencode.md`](opencode.md) | `~/.config/opencode/` |
| Antigravity | [`antigravity.md`](antigravity.md) | `~/.gemini/antigravity-cli/` |
| Cursor | [`cursor.md`](cursor.md) | `~/.cursor/` |

Deeper, version-specific research (kept for reference, **not** authoritative) is
under [`docs/harness-research/`](../../docs/harness-research/).
