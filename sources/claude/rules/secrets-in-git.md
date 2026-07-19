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

## User-Facing Channel Allowlist

Secrets MAY appear ONCE in the active Claude chat session — so the user can copy-paste into the right CLI (`vercel env add`, `convex env set`, `pass insert`, etc.). They MUST NOT appear in any persisted artifact (file on disk inside the repo, commit, PR, issue, gist, tag, branch name).

The chat itself is not "persisted" in the GitHub-leak sense: it lives in the user's local Claude history and is not searchable/indexable by third parties. That is the only legitimate channel for raw secret values during a workflow.

## Redaction Conventions (use these in commit/PR/issue bodies)

When you need to *reference* a secret in a body, use one of these placeholders:

- `<set via vercel env add APP_PROXY_SECRET production>` — for Vercel-stored values
- `<set via convex env set APP_PROXY_SECRET>` — for Convex-stored values
- `<set via chat session>` — when raw was shown to user once for manual copy-paste
- `<rotated secret — see chat session>` — for incident-response bodies after rotation
- `<REDACTED:KIND>` — generic catch-all (e.g. `<REDACTED:JWT>`, `<REDACTED:HEX32>`)

Never paste even a partial real secret — half a JWT is still recoverable.

## Rotation when a leak is detected

If a secret reaches GitHub: rotate immediately at source, update all envs (Vercel/Modal/Convex), revoke the old value, document the incident, then optionally redact in GitHub. Full 5-step runbook: `~/.claude/runbooks/secrets-in-git-runbook.md`.

## Enforcement: ggshield is the gate (since 2026-07-18)

GitGuardian's `ggshield` enforces this rule automatically on two layers:

- **Global git pre-push hook** (`ggshield install --mode global -t pre-push`, via global `core.hooksPath`) — scans every push before it leaves the machine. Husky repos (shared-canvas, svb-elektrschiess) shadow the global hooksPath; they carry their own `.husky/pre-push` with `ggshield secret scan pre-push "$@"`.
- **Claude Code hook** (`ggshield secret scan ai-hook`, PreToolUse in `~/.claude/settings.json`) — blocks secrets before they reach prompts/tool calls.

Auth: `ggshield auth login` (token in macOS keyring — NOT readable from the Bash sandbox, so sandboxed `ggshield api-status` reports "no token"; that is sandbox noise, not a broken auth). Dashboard-Ignores propagate to ggshield, so triaged test fixtures stay quiet.

The NEVER-list above still applies to what the agent *authors* (commit messages, PR bodies, gists — content ggshield may not scan). The redaction conventions remain mandatory. Pattern details for judgment calls: `secrets-in-git-patterns.md`.

(History: a homegrown scanner hook was retired 2026-07-16 at 88 % false-positive rate; ggshield replaced it 2026-07-18 — same intent, battle-tested engine.)
