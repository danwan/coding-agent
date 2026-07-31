# Hooks (Claude Code implementation)

These hooks are implemented for **Claude Code** and live on the machine at
`~/.claude/hooks/` with their wiring in `~/.claude/settings.json` (the exact
wiring is captured in `settings-hooks.json` here — merge it into the `hooks`
key of the settings file).

| Script | Event | Purpose |
|---|---|---|
| `check-backend-deploy.sh` | PreToolUse on `git push*` | Warn when pushing frontend changes while backend (Convex/Modal) is undeployed |
| `session-start.sh` | SessionStart | Print repo status summary (branch, ahead/behind hint) into session context |
| `format-python.sh` | PostToolUse on `*.py` Write/Edit | Auto-format Python after edits |
| `format-typescript.sh` | PostToolUse on `*.ts`/`*.tsx` Write/Edit | Auto-format TypeScript after edits |

Machine-specific hooks installed by third-party apps (e.g. Orca) are NOT part
of this repo — only the authored hooks above are.

## Scripts self-filter; wiring is only an optimization

Each script decides for itself whether it applies: the formatters check the file
extension, `check-backend-deploy.sh` checks that the command is a push. Claude
Code's `if:` field then avoids even spawning them, but correctness does not
depend on it — other harnesses have no equivalent, and a hook that never matches
looks exactly like a hook that matched and found nothing.

Two live examples of that failure mode, both found on 2026-07-31:

- Codex had the formatters wired to `Stop` instead of `PostToolUse`. A `Stop`
  payload carries no `tool_input.file_path`, so both scripts read an empty path
  and exited 0. They had never formatted anything.
- `check-backend-deploy.sh` compared against the local default branch while
  standing on it, making the production path unreachable, and emitted a response
  shape with no recognized fields.

**So: pick the event that actually carries the data the script needs, and prove
it with a payload before trusting the wiring.**

The formatters now say so themselves: given a payload with no
`.tool_input.file_path` they print one line to stderr instead of exiting 0
quietly. A wrong event or a foreign payload schema is therefore visible on the
first run rather than never.

## Which harness gets which hook, and why not all of them

| Harness | Hooks placed | Reasoning |
| --- | --- | --- |
| Claude Code | all four | native |
| Codex | all four | Claude-compatible events and response shape |
| Factory Droid | all four | Claude-compatible protocol. **Hooks live in `settings.json`, not `hooks.json`** — the docs say the opposite; determined by putting a sentinel in both and running `droid exec` once. Only the `settings.json` sentinel fired. |
| Gemini / Antigravity | formatters only | Its events are named differently (`AfterTool`, not `PostToolUse`) and the payload field names are undocumented. Formatters act by side effect, so a schema mismatch is caught by the diagnostic above. |
| Cursor | formatters only | Response protocol differs (`permission: allow\|deny\|ask`, not `hookSpecificOutput`), so `check-backend-deploy.sh` would run and have its verdict discarded — a guard that cannot act. Formatters are unaffected because they act by side effect. |
| Windsurf | none | Control flow is exit-code only, event names are snake_case and unrelated. Porting means rewriting, not copying. |

The pattern: **a hook that acts by side effect ports across harnesses; a hook
that acts through a response protocol only ports where that protocol matches.**

## For non-Claude agents provisioning from this repo

The hook **logic** is portable, but the checked-in scripts consume Claude's
hook JSON and emit Claude's response shape. A non-Claude harness must translate
both the wiring and that input/output protocol. Do not copy the scripts
verbatim and assume they are harness-agnostic. If the harness supports
equivalent events, implement equivalent scripts from the behavior described in
the table; otherwise skip them. Codex-specific details live in
`sources/harness-notes/codex.md`.
