# Secrets in Git/GitHub Artifacts — Background, Rotation

> Companion runbook for `~/.claude/rules/secrets-in-git.md`. NOT auto-loaded.
> Consult on-demand: when investigating a leak or running incident response
> after a real secret hits GitHub.

## Background — the 2026-04-29 incident

A Claude session embedded a freshly-generated APP_PROXY_SECRET into a `gh pr
create --body` argument. Local commits were clean (placeholder used), the
PR-description leaked. GitHub retains PR/issue edit-history, search index,
webhook payloads (CodeRabbit, Vercel, Slack), notification mails, and audit
logs. The secret had to be rotated. The `secrets-in-git.md` rule — self-
enforced before every publish, there is no automated scanner in this setup —
exists to prevent the recurrence.

### Why GitHub-side persistence is unrecoverable

GitHub-side persistence is multi-layered and ALL of it is out of your control
once the value is published:

- **Edit-history:** Editing a PR/issue body via the API or web UI keeps prior
  versions accessible via the audit log API and via "edited" UI affordances.
- **Search index:** Code-search and issue-search index the raw text including
  past versions on private repos as well.
- **Webhooks:** CodeRabbit, Vercel, Slack, custom webhooks receive the
  original payload before edit. Their logs are not yours.
- **Notification mails:** Every watcher gets the original body in their inbox
  immediately. No edit reaches that mailbox.
- **Backups + GHE audit logs:** Long-retention storage even on deletion.
- **Forks + cache:** If the repo ever turns public, history snapshots may
  surface in third-party caches.

Even on private repos, the secret is functionally burned the moment it hits
GitHub. Treat it as compromised → rotate.

## Rotation runbook (when a leak is detected)

1. **Rotate immediately.** Generate a new value at the source (Convex/Vercel
   dashboard, Stripe dashboard, env-var manager). Don't delegate.
2. **Update `.env` + deployment env.** Push to all environments (Vercel,
   Modal, Convex) before anything else.
3. **Revoke the old value.** Where supported (Stripe, GitHub PAT, AWS),
   explicitly revoke the leaked key.
4. **Document the incident.** Append to project `TROUBLESHOOTING.md` or
   create `docs/incidents/YYYY-MM-DD-<name>.md`: when, where leaked, who
   could read it, what was rotated.
5. **Then optionally redact.** GitHub support / `git filter-repo` / PR-body
   edit — treat as PR-hygiene, not security. The original value is already
   burned.

## No automated scanner — self-enforce

There is no hook or scanner in this setup that blocks secret-bearing publishes.
`secrets-in-git.md` and `secrets-in-git-patterns.md` are self-enforced: check
the NEVER-list and pattern catalog against the diff/body yourself before every
commit, tag, branch name, PR/issue/gist/release, or comment that leaves the
local repo.
