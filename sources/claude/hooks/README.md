# Hooks (Claude Code implementation)

One hook remains. It is implemented for **Claude Code** and lives on the machine
at `~/.claude/hooks/` with its wiring in `~/.claude/settings.json` (the exact
wiring is captured in `settings-hooks.json` here — merge it into the `hooks` key
of the settings file).

| Script | Event | Purpose |
|---|---|---|
| `check-backend-deploy.sh` | PreToolUse on `git push*` | Warn when pushing frontend changes while backend (Convex/Modal) is undeployed |

Machine-specific hooks installed by third-party apps (e.g. Orca) are NOT part
of this repo — only the authored hook above is.

## Why only this one

A hook earns its place by catching something no other layer catches.
`check-backend-deploy.sh` qualifies: Convex and Modal do not auto-deploy (Golden
Rule #7), so a push of frontend code referencing un-deployed backend changes
crashes at runtime, in production, and nothing else on this machine notices. It
answers `permissionDecision: "ask"`, so the push stops and the user decides.

Three hooks were removed on 2026-07-31 for failing that bar:

- **`format-python.sh` / `format-typescript.sh`** (PostToolUse on Write/Edit) —
  ran `ruff` / `prettier` on the file just written. What they bought was diff
  cosmetics, which format-on-save and pre-commit hooks already handle at the
  right moment. What they cost was five copies across five harnesses, each with
  its own payload schema to keep translated — and one of those copies had never
  worked (see below).
- **`session-start.sh`** (SessionStart) — printed
  `Branch: x | Modified: n | Ahead: n`. A `git status` produces the same three
  numbers on demand. Worse, it never fetched, so its ahead/behind could read "in
  sync" against a stale ref; `rules/git-freshness.md` carried a dedicated rule
  warning readers not to trust it. A hook that needs a rule explaining why not to
  believe it is a net loss.

## The lesson worth keeping

Every hook is a claim that something runs. Verify the claim with a real payload
before trusting it — the same event name across two harnesses does not mean the
same event data, and **a hook that never matches looks exactly like a hook that
matched and found nothing.**

Both failure modes were live here, found on 2026-07-31:

- Codex had the formatters wired to `Stop` instead of `PostToolUse`. A `Stop`
  payload carries no `tool_input.file_path`, so both scripts read an empty path
  and exited 0. They had never formatted anything, for as long as they had been
  installed.
- `check-backend-deploy.sh` compared against the *local* default branch while
  standing on it, making the diff always empty and the production path
  unreachable. It also emitted a response shape with no recognized fields, so
  even a correct verdict would have been discarded.

The surviving hook is written accordingly: it re-checks the command itself
rather than trusting Claude Code's `if:` pre-filter, because that field has no
equivalent on other harnesses and correctness must not depend on it.

## For non-Claude agents provisioning from this repo

The hook **logic** is portable, but the checked-in script consumes Claude's hook
JSON and emits Claude's response shape. A non-Claude harness must translate both
the wiring and that input/output protocol. Do not copy the script verbatim and
assume it is harness-agnostic.

Note the asymmetry that governed the earlier per-harness rollout: **a hook that
acts by side effect ports across harnesses; a hook that acts through a response
protocol only ports where that protocol matches.** With the formatters gone,
only the second kind is left. Install `check-backend-deploy.sh` where the
response protocol is Claude-compatible (Codex — see
`sources/harness-notes/codex.md`; Factory Droid, whose hooks live in
`settings.json`, not `hooks.json`, contrary to its docs). Skip it where the
protocol differs — Cursor uses `permission: allow|deny|ask` rather than
`hookSpecificOutput` and would discard the verdict, and Gemini/Antigravity names
its events differently (`AfterTool`) with undocumented payload fields. A guard
that cannot act is worse than no guard: it reports green either way.
