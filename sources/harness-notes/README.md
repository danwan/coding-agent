# Harness notes

`sources/claude/` is the **single source of truth** for all authored content
(instructions, rules, subagents) — written in Claude Code's format.
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
| Antigravity / Gemini | [`antigravity.md`](antigravity.md) | `~/.gemini/` |
| Cursor | [`cursor.md`](cursor.md) | `~/.cursor/` |
| Factory Droid | [`droid.md`](droid.md) | `~/.factory/` |

## Placement is mechanized — `../../sync.sh`

Copies drift only because nobody re-copies them. `sync.sh` at the repo root
places the canonical content into every installed harness, skips the ones that
are absent, and is idempotent: run it with no arguments for a dry run, with
`--apply` to write. That is the maintenance answer to "why does Codex still have
last month's rules".

Harnesses get **copies, never symlinks into this repo.** A symlink would make
`git checkout <old-branch>` silently rewrite every agent's global instructions,
and would break all of them if the repo moved.

## What the harnesses genuinely cannot share

These are not preferences; they are limits that make "100 % identical" false in
places, and it is better to name them than to pretend otherwise.

| Constraint | Consequence |
| --- | --- |
| Codex has no rules directory | The rules are concatenated into `AGENTS.md`, bounded by `project_doc_max_bytes`. |
| Cursor documents no global instruction file | `~/.cursor/rules/*.mdc` is an undocumented path. Rules there need `.mdc` **with** frontmatter — a plain `.md` is silently ignored. |
| Gemini's `GEMINI.md` is shared with plugin-managed blocks | Merge into a marked block; overwriting destroys the Context7 instructions. |
| OpenCode has no shell-hook system | Its plugins are JS/TS event handlers. (Moot for now — no hooks are authored anymore.) |

## Deliberately out of scope

**Windsurf.** Its only global surface is one file capped at 6 000 characters with
no rules directory, its hooks are exit-code-only with unrelated event names, and
it documents no user-defined subagents — so it could never carry this content and
every attempt would have to be a second, separately-maintained short version.
It is not provisioned, not synced, and not verified here. That is a scope
decision, not an oversight: if it comes back, it needs its own note and its own
abbreviated ruleset, not a carve-out in the shared path.

Deeper, version-specific research (kept for reference, **not** authoritative) is
under [`docs/harness-research/`](../../docs/harness-research/).
