# AGENTS — Operating Rules

- **`PROVISION.md` is the single source of truth.** It states intent (what,
  from where, why, verify) — not install commands.
- **The agent provisions from current mechanisms.** Read your own current
  docs and adapt to whatever package manager, marketplace, or config format
  is current when you run this. The intent is the contract, not any specific
  command.
- **Authored content is stored once, in Claude format.** `sources/claude/` is
  the single source of truth (CLAUDE.md, rules, runbooks, agents). Non-Claude
  harnesses translate it at provision time via `sources/harness-notes/<harness>.md`
  — keep those notes principle-based, not version-pinned. Never commit a
  pre-translated per-tool copy of the authored content; it only drifts.
- **Prune always asks.** Never auto-delete anything found installed but not
  listed in `PROVISION.md`. Ask the user whether to remove it or add it to
  `PROVISION.md`.
- **Stack skills are project-local by default.** Install them per-project
  (`npx skills add` without `-g`, committed to that project's repo). A small
  cross-project global exception is allowed only when `PROVISION.md` names the
  exact skill and canonical source; do not grow that exception implicitly.
- **Secrets never in repo.** Only secret names and `op://` references belong
  here. Values are resolved via the 1Password CLI or asked for interactively
  — never written to a file in this repo.
- **Git is HTTPS via `gh`.** No SSH remotes.
- **All commits, PRs, and messages use user's account.** All commits, PRs, and messages must always be done using the user's account and name only (never attribute to Claude or any other AI identity).
