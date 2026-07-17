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

## For non-Claude agents provisioning from this repo

The scripts are plain shell and harness-agnostic; only the wiring is
Claude-specific. **Check your own current documentation for a hook/event
mechanism** (lifecycle hooks, event bus, plugin hooks, etc.). If your harness
supports equivalents of the events above, wire these scripts in. If not, skip
them — they are conveniences, not required guardrails.
