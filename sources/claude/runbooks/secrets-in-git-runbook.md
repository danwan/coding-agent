# Secrets in Git/GitHub Artifacts — Background, Audit, Rotation

> Companion runbook for `~/.claude/rules/secrets-in-git.md`. NOT auto-loaded.
> Consult on-demand: when investigating a leak, auditing the FP rate of the
> hook, or running incident response after a real secret hits GitHub.

## Background — the 2026-04-29 incident

A Claude session embedded a freshly-generated APP_PROXY_SECRET into a `gh pr
create --body` argument. Local commits were clean (placeholder used), the
PR-description leaked. GitHub retains PR/issue edit-history, search index,
webhook payloads (CodeRabbit, Vercel, Slack), notification mails, and audit
logs. The secret had to be rotated. The `secrets-in-git.md` rule and
`pre-publish-secret-scan.sh` hook prevent the recurrence.

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

## Audit log analysis

Every BLOCK and OVERRIDE event from `pre-publish-secret-scan.sh` appends one
TSV line to `~/.claude/logs/pre-publish-secret-scan.log`:

```
<UTC-ISO-timestamp>\t<BLOCK|OVERRIDE>\t<sanitized-cmd-type>\t<matched-pattern-names>
```

- `sanitized-cmd-type` strips body content at the first quote and replaces
  unquoted flag values with `<…>` (e.g. `git checkout -b <…>`, `gh pr create
  --title <…> --body`). By design, no body content or flag value is ever
  logged — so a blocked secret can never leak into the log itself.
- APPROVE events are not logged (would be noise in the success path).

### Cookbook queries

```bash
# Total fires by verdict:
awk -F'\t' '{print $2}' ~/.claude/logs/pre-publish-secret-scan.log \
  | sort | uniq -c

# Most-triggered patterns (BLOCK only):
awk -F'\t' '$2=="BLOCK"{print $4}' ~/.claude/logs/pre-publish-secret-scan.log \
  | tr '|' '\n' | sort | uniq -c | sort -rn

# Override usage (genuine FPs the user accepted):
awk -F'\t' '$2=="OVERRIDE"{print $1, $3}' ~/.claude/logs/pre-publish-secret-scan.log

# Last 20 BLOCKs (sample for FP triage):
grep BLOCK ~/.claude/logs/pre-publish-secret-scan.log | tail -20
```

### Snapshot 2026-05-07

```
Total entries: 268
  BLOCK:     262
  OVERRIDE:    6

Top patterns by BLOCK count:
  252  Base64-like string ≥ 40 chars (digits + letters)
   18  OpenAI/Anthropic API key
   17  Hex string ≥ 32 chars (commit-SHA refs already excluded)
    5  ENV-style sensitive assignment
    4  GitHub PAT
    2  JWT triplet
    2  Convex deploy key
    1  AWS Access Key
```

Note: The Base64 pattern dominates at 96% of all BLOCKs. Without inspecting
the original commands (which the hook deliberately does NOT log), it is
impossible to determine the FP rate for this pattern. The 6 OVERRIDE entries
suggest the user mostly accepted blocks — which is consistent either with
"most blocks were real catches" or "user adapted by not committing those
strings".

## Hook reference

`~/.claude/hooks/pre-publish-secret-scan.sh` enforces the rule at the
Bash-PreToolUse layer. Triggers: `gh pr create/edit/comment`, `gh pr review`,
`gh issue create/edit/comment`, `gh gist create/edit`, `gh release
create/edit`, `git commit -m/-am/-F/--message/--file`, `git tag
-a/-m/--annotate`, `git branch -m`, `git checkout -b`, `git switch -c`. See
`~/.claude/settings.json`.

The hook is a guard, not a rewriter — it blocks and surfaces; the agent (or
user) decides how to redact.
