# Git Freshness (Verify Sync Before Reasoning on Repo State)

> Before you analyze, classify, or decide anything from git state, confirm your view of the remote is current — and if it isn't, say so. Never reason on a stale snapshot silently. Extends Golden Rule #9 in `~/.claude/CLAUDE.md`.

## Why this rule exists

Local remote-tracking refs (`origin/main`, `[gone]` markers, `ahead/behind` counts) are only as fresh as your last successful `git fetch`. A clone that hasn't fetched — or whose fetch was blocked (sandbox SSH denial, network, auth) — will report a confident but **wrong** picture: "unmerged work" that is actually merged, "behind by N" that is really behind by N+M, branches that look deletable but aren't (and vice versa). The failure is silent because every downstream `git log`/`git diff`/`git cherry` runs happily against the stale refs.

This bit us once already: a `git fetch ... 2>/dev/null || true` swallowed a sandbox-blocked SSH fetch, the audit ran on a 1-commit-stale `main`, and a branch that had been squash-merged to production got classified as "keep — unmerged work."

## The rule

1. **Fetch before you reason.** Any task that draws conclusions from git state (merge status, branch cleanup, "is X already on main", behind/ahead, `[gone]` detection) starts with `git fetch --all --prune` — not a cached view.
2. **Verify the fetch succeeded — fail loud if not.** Never `2>/dev/null || true` a fetch whose result you then trust. If the fetch fails (network, auth, or sandbox port-22 on a raw-SSH remote), **surface it explicitly** and label every git-derived finding as "based on a possibly stale local state." Do not present stale findings as fact. **Judge success by the exit code, not by grepping output for `fatal`** — see the keychain caveat below.
3. **Sandbox + HTTPS (no SSH).** Git uses HTTPS to github.com via the `gh` credential helper (Golden Rule #2), and a global `url.insteadOf` rewrites SSH remotes → HTTPS. Because `github.com` is in the sandbox network allowlist, `git fetch`/`pull`/`push` run **inside** the sandbox prompt-free — no `dangerouslyDisableSandbox` needed. Two gotchas:
   - **Harmless keychain noise:** a `fatal: failed to store: 100001` (or similar) line printed with **exit 0** is the credential-helper's keychain *write-back* being blocked by the sandbox. The fetch itself **succeeded** (refs updated, `FETCH_HEAD` fresh). Do not classify this as a failure — it is by-design and non-blocking.
   - **Raw-SSH remote fallback:** if a remote is still `git@github.com:` with no `insteadOf` rewrite in effect, the sandbox blocks port 22 (`authentication method negotiation failed` / `Connection closed by UNKNOWN port`) and the fetch genuinely fails. Fix by switching the remote/transport to HTTPS, or retry with the sandbox disabled (the user can manage this via `/sandbox`), then re-verify.
4. **Always report divergence.** When you state repo/branch status, include local-vs-`origin` `ahead/behind` so the user can see drift. `EQUAL` is a claim that needs a fresh fetch behind it.
5. **The SessionStart summary is not a sync check.** `session-start.sh` reports `Ahead/Behind` from local `@{upstream}` *without fetching* — it can read "in sync" while `origin` has moved. Treat it as a hint, not proof of freshness.

## Pre-action check

*"Have I fetched, did the fetch actually succeed, and am I reporting ahead/behind — or am I about to classify merge/branch state from refs that could be stale and call it fact?"*
