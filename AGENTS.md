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
- **Stack skills are project-local.** Convex, Vercel, Next.js, Modal, and
  other stack-specific skills install per-project (`npx skills add` without
  `-g`, committed to that project's repo) — never globally from this repo.
- **Secrets never in repo.** Only secret names and `op://` references belong
  here. Values are resolved via the 1Password CLI or asked for interactively
  — never written to a file in this repo.
- **Git is HTTPS via `gh`.** No SSH remotes.
