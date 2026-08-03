# Global Rules

These rules apply to every project on this machine. A project `CLAUDE.md` adds to
them; it overrides only the individual rules it contradicts. Rule files referenced
below do not load themselves — open them before acting.

## E — This machine

- **E1** Python: deps in `.venv` via uv, run with `uv run …`.
- **E2** Git: always the CLI, and never disable the sandbox for it. Remotes may print
  as SSH — a global `insteadOf` rewrite sends them over HTTPS via the `gh` credential
  helper, so fetch/pull/push run inside the sandbox. Port 22 is not allowlisted.
- **E3** `curl --max-time 10`, always.
- **E4** `main` deploys to production. Every other branch is preview/dev.
- **E5** CLI calls run unattended: `-y` on Vercel and Modal, and `printf` rather than
  `echo` for env values — a trailing newline corrupts secrets.
- **E6** Convex and Modal do not auto-deploy. Deploy the backend before testing a
  frontend against it. If you use it local for testing ensure the latest database is running, with latest updates.
- **E7** Secrets never enter the agent's context. Resolve a secret only inside a
  subprocess that consumes it directly — `op run --env-file=… -- <cmd>`, or
  `op read '<op://…>' | <cmd>` piped straight into the tool. Never `op read` a value
  to stdout, `cat`/`grep` a real secret out of an `.env`, or `echo` a key, so that the
  value lands in tool output the model reads. To liveness-test a key, surface only the
  HTTP status, a character count, or a one-way hash — never the value itself. Any secret
  value that does reach the context is considered compromised and must be rotated. This
  is why `op run`/piping exists: the shell sees the key, the model never does.

## W — Working

- **W1** A bug fix starts with a test that reproduces it and fails. For a feature,
  name the one observable check that proves it works.
