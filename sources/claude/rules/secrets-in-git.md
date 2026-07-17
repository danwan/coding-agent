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

## No automated scanner — self-enforce

This is a hard rule, not a hook-enforced one: there is no automated scanner in this setup. Before every commit/push, self-check the diff/body against the NEVER-list above. Pattern details: see `secrets-in-git-patterns.md` (loads when editing `.env*` files).

(An earlier scanner hook was retired on 2026-07-16 due to an 88 % false-positive rate — it mainly tripped on the mandated `Claude-Session:` commit trailer and long paths. Archived under `~/.claude/dan-backup/`.)
