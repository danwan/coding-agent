# Secrets in Git/GitHub Artifacts (Never)

> Pattern catalog, FP-whitelist: `~/.claude/rules/secrets-in-git-patterns.md` (path-scoped to `.env*` etc.)
> Rotation runbook: `~/.claude/runbooks/secrets-in-git-runbook.md`

## NEVER include secret values in:

- Commit messages (`git commit -m`, `-F`, `--message`, `--file`, HEREDOC bodies)
- Tag annotations (`git tag -a`, `-m`, `--annotate`)
- Branch names (`git branch -m`, `git checkout -b`, `git switch -c`)
- PR titles + descriptions (`gh pr create`, `gh pr edit`)
- PR review/comment bodies (`gh pr comment`, `gh pr review --body`)
- Issue titles + bodies (`gh issue create`, `gh issue edit`)
- Issue comment bodies (`gh issue comment`)
- Gist content (`gh gist create`, `gh gist edit`)
- Release notes (`gh release create --notes`, `--notes-file`)
- Any other text the agent itself authors and pushes to GitHub

Once a secret hits GitHub, treat it as compromised → rotate. See runbook.

## User-Facing Secret Handling

Do not ask the user to paste raw secret values into an agent chat. Agent chats,
tool transcripts, histories, screenshots, and diagnostics may persist. Have the
user enter the value directly into the destination CLI, keychain, 1Password
prompt, or provider dashboard. The agent may handle secret names and
`op://` references, never the resolved value.

## Redaction Conventions (use these in commit/PR/issue bodies)

When you need to *reference* a secret in a body, use one of these placeholders:

- `<set via vercel env add APP_PROXY_SECRET production>` — for Vercel-stored values
- `<set via convex env set APP_PROXY_SECRET>` — for Convex-stored values
- `<set directly by user>` — when the user entered the value outside the agent
- `<rotated secret>` — for incident-response bodies after rotation
- `<REDACTED:KIND>` — generic catch-all (e.g. `<REDACTED:JWT>`, `<REDACTED:HEX32>`)

Never paste even a partial real secret — half a JWT is still recoverable.

## Rotation when a leak is detected

If a secret reaches GitHub: rotate immediately at source, update all envs (Vercel/Modal/Convex), revoke the old value, document the incident, then optionally redact in GitHub. Full 5-step runbook: `~/.claude/runbooks/secrets-in-git-runbook.md`.

## Enforcement: ggshield is the gate when quota is available

After authentication, confirm `ggshield quota` is greater than zero. Only then
enable these two layers:

- **Global git pre-push hook** (`ggshield install --mode global -t pre-push`, via global `core.hooksPath`) — scans every push before it leaves the machine. Husky repos (shared-canvas, svb-elektrschiess) shadow the global hooksPath; they carry their own `.husky/pre-push` with `ggshield secret scan pre-push "$@"`.
- **Agent hook** (`ggshield secret scan ai-hook`) — install the native target
  for the active harness (`claude-code` or `codex`) so prompts/tool calls are
  scanned using that harness's supported hook schema.

Auth: `ggshield auth login` (token in the OS keyring). Verify with
`ggshield api-status`, `ggshield quota`, and a benign scan. If quota is zero,
disable both hooks: the pre-push hook blocks normal pushes and the agent hook
can only fail open with repeated warnings. Do not treat an authentication or
quota failure as harmless. Dashboard-Ignores propagate to ggshield, so triaged
test fixtures stay quiet.

The NEVER-list above still applies to what the agent *authors* (commit messages, PR bodies, gists — content ggshield may not scan). The redaction conventions remain mandatory. Pattern details for judgment calls: `secrets-in-git-patterns.md`.

(History: a homegrown scanner hook was retired 2026-07-16 at 88 % false-positive rate; ggshield replaced it 2026-07-18 — same intent, battle-tested engine.)
