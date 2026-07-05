---
name: branch-cleanup
description: >
  Take a single git repo with many branches and mixed PR states back to a clean main:
  audit all branches and PRs, auto-merge fully-green PRs, prune [gone], merged, and
  squash-merged branches, propose rebase/merge for behind-main branches, surface failing-CI
  excerpts, and ask only before destructive batches. Always dry-run-able. Trigger for BULK
  branch/PR convergence — "clean up branches", "merge everything mergeable", "wrap up
  branches", "converge to main", "prune merged branches", "my repo is a mess", tidying up
  before a break — and German equivalents ("branches aufräumen", "alles auf main mergen",
  "vor dem Urlaub aufräumen", "Aufräumen"). Do NOT trigger for a single-PR merge, a
  single-branch rebase, one known conflict you understand, or multi-repo sync (that is
  git-sync's job).
effort: medium
---

# Branch Cleanup

Take a single git repo from "many branches, mixed PR states, drift from main" to "clean main, clear status on every remaining branch." Five phases. Each phase has a checkpoint. The skill never silently destroys work.

**Scripts** (in `scripts/`):
- `audit.sh` — Phase 1, read-only state report. Save its stdout to a file so `plan.sh` can reuse it.
- `plan.sh [audit-file]` — Phase 2, generates the cleanup/merge plan. Pass the saved audit output so it doesn't re-run the audit (and its fetch + CI-log fetches) a second time.
- `safe-delete.sh` — Phase 4/5, deletes a branch with worktree + safety checks
- `try-merge.sh` — Phase 5, attempts a merge and classifies the result

These scripts degrade gracefully. If `gh` is missing, unauthenticated, or the repo has no GitHub remote, the audit still reports every local-branch fact and marks `GH_STATE` so the plan skips only the PR-dependent phases. A local-only repo with no remote at all is a valid input — the skill just does branch hygiene.

**References** (in `references/`, read on demand):
- `pr-verification.md` — `gh` CLI patterns for green/approved/conflict gates
- `conflict-handling.md` — when auto-commit is safe vs when to abort
- `failing-ci-diagnosis.md` — fetching log excerpts without attempting fixes

## Why this skill exists

Branch hygiene is fragmented across many tools (`git fetch --prune`, `git branch -d`, `gh pr merge`, `clean_gone`, `git-sync`). Each is correct in isolation but the user has to thread them together by hand and remember the safe order. This skill is the orchestrator: it runs the right tool at the right time, asks before anything destructive, and leaves a written before/after report.

This is **single-repo** scope on purpose. Multi-repo sweeps are `git-sync`'s job. Use both: `git-sync` to find which repos need attention, then `branch-cleanup` per repo for the deep clean.

## Invocation

User says one of the trigger phrases (English or German), or runs the skill explicitly. Default mode is **dry-run for everything destructive** until the user approves the plan. Add `live` or "execute" to the prompt to actually apply changes — but never skip Phase 2 approval.

## Phase 1 — Audit (read-only, always safe)

Capture the output to a file so Phase 2 can reuse it instead of auditing twice:
```bash
bash ~/.agents/skills/branch-cleanup/scripts/audit.sh > "$TMPDIR/branch-cleanup-audit.txt"
```
`STALE_DAYS=<n>` overrides the stale-by-time threshold (default 90).

The script writes a structured block to stdout. Parse it and present as a summary table:

| Section | Content |
|---|---|
| **Fetch status** | `FETCH_STATUS=OK`, `NO_REMOTE`, or `FAILED: …` — the refresh of remote refs |
| **Working tree** | clean / dirty (with file count); stash count |
| **Local branches** | grouped: on-main / ahead-of-main / behind-main / diverged / [gone] / squashed / stale-by-time |
| **Remote branches** | branches on the primary remote not present locally |
| **GitHub state** | `GH_STATE=OK` or a degraded reason (see below) |
| **Open PRs** | grouped: mergeable-green / blocked-by-conflict / blocked-by-ci / blocked-by-review / draft / unknown-mergeability |
| **Failing CI excerpts** | for each blocked-by-ci PR: failing job name + first 20 log lines |

**Hard checkpoint after audit (freshness):** if `FETCH_STATUS` is neither `OK` nor `NO_REMOTE`, the remote refs are stale and every merge/`[gone]`/behind classification below may be wrong. STOP, surface the failure verbatim, and do not present findings as fact. If the cause is the sandbox blocking SSH (`authentication method negotiation failed` / `Connection closed by UNKNOWN port`), retry the fetch with the sandbox disabled, then re-run the audit. See `~/.claude/rules/git-freshness.md`. (`NO_REMOTE` is not a failure — it means a local-only repo; proceed with local hygiene.)

**Degraded GitHub state:** `GH_STATE` tells you *why* PR data may be absent so you can be honest with the user rather than silently dropping half the workflow:
- `OK` — PR data is present; run all phases.
- `NO_GH_CLI` / `NOT_AUTHENTICATED` / `NO_GITHUB_REMOTE` — PR phases (4 + the PR parts of 5) don't apply. Tell the user which one it is and continue with local branch hygiene (Phases 3 + 5a/5b/5c). For `NOT_AUTHENTICATED`, mention `gh auth login` as the fix if they want PR handling too.
- `ERROR` — surface `GH_ERROR` verbatim and treat PRs as unknown.

**Hard checkpoint after audit (dirty tree):** if the working tree is dirty, every later phase that switches branches is unsafe. Offer the user a choice rather than a dead end: (a) commit, (b) let the skill `git stash push -u` now and `git stash pop` in the final report, or (c) abort. Don't proceed to branch-switching phases until the tree is clean.

## Phase 2 — Plan (read-only)

Run, reusing the audit you already captured (falls back to a fresh audit if you omit the arg):
```bash
bash ~/.agents/skills/branch-cleanup/scripts/plan.sh "$TMPDIR/branch-cleanup-audit.txt"
```

The script produces a markdown plan with four sections:

1. **Auto-merges** — PRs passing all three gates (checks green + approved + zero conflicts). Will execute in Phase 4 without asking.
2. **Manual decisions** — PRs failing one or more gates, behind/diverged branches, `[gone]`-with-unique-work branches, unknown-mergeability PRs.
3. **Cleanup** — `[gone]`-and-in-main, merged-into-main, and squash-merged locals. Will delete in Phase 5 after main is up-to-date.
4. **Order** — numbered steps with dependencies. Auto-merges first (so main moves), then dependent rebases, then deletes.

Every branch appears in **exactly one** bucket. The classifier de-duplicates by priority (cleanup-safe > gone-with-work > stale > behind/diverged), so the user is never asked twice about the same branch — e.g. a squash-merged branch shows up only under "squash-merged cleanup", not also under "diverged". Commit subjects are passed to the classifier through a file, never interpolated into shell — a branch whose commit message contains backticks or `$(...)` is data, not a command.

The plan is written to `$TMPDIR/branch-cleanup-<repo>-<ts>.md` so it survives mid-session re-reads.

**Hard checkpoint after plan:** show the plan to the user, ask for one of:
- **approve all** → continue to Phase 3
- **amend** → user edits the plan file, rerun plan validation
- **abort** → stop, no changes made

Do not proceed without explicit approval. Approval here is the analog of `ExitPlanMode` for the skill itself.

## Phase 3 — Sync main (low risk, mostly mechanical)

Make `main` (or the repo's default branch — detect via `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`) up to date locally and remotely. Steps:

1. **Safety tag** — `git tag claude-cleanup-backup-$(date +%s) HEAD` so any branch the skill touches can be recovered. Tell the user the tag name.
2. **Enable rerere + autoupdate** — `git config rerere.enabled true && git config rerere.autoupdate true`. Idempotent. Why both: `rerere.enabled` records and replays resolutions on identical conflicts; `rerere.autoupdate` *stages* the replayed resolution so the index has zero unmerged paths afterward. Without autoupdate, a replayed resolution sits in the working tree but the index still shows the conflict — `try-merge.sh`'s "did rerere resolve everything?" check would never fire and it would abort a merge it could have completed. Background in `references/conflict-handling.md`.
3. **Fetch + prune** — `git fetch --all --prune`. Removes stale remote-tracking refs.
4. **Switch to default branch** — `git switch main` (or detected default).
5. **Fast-forward main** — `git merge --ff-only origin/main`. If this fails, main has diverged from origin/main, which is unusual for a non-PR branch; **stop and report**, don't try to merge or rebase.
6. **Push if main is ahead** — `git push origin main`. Only happens if the user merged something locally without pushing.

After Phase 3, `main` and `origin/main` are bit-identical.

## Phase 4 — Auto-merge green PRs (medium risk)

If `GH_STATE` was not `OK` in the audit, skip this phase entirely — there are no PRs to act on — and say so. Otherwise, for each PR in the "auto-merges" group from the plan:

1. **Re-verify gates immediately before merging.** State can change between audit and merge (a teammate could have added a review or pushed a commit). Run:
   ```bash
   gh pr view "$N" --json mergeable,mergeStateStatus,reviewDecision,statusCheckRollup
   ```
   Required: `mergeable == "MERGEABLE"`, `reviewDecision == "APPROVED"`, every entry in `statusCheckRollup` has `conclusion == "SUCCESS"` or is in a known-pass state. Details in `references/pr-verification.md`.

2. **Detect repo's allowed merge methods** once per session:
   ```bash
   gh repo view --json mergeCommitAllowed,squashMergeAllowed,rebaseMergeAllowed
   ```
   Prefer squash if allowed (clean main history); fall back to merge, then rebase. Never force a method the repo disabled.

3. **Echo before merge** — print "Merging PR #N (<title>) via <method>, branch <branch> will be deleted." Then:
   ```bash
   gh pr merge "$N" --squash --delete-branch
   ```

4. **After each merge:** `git switch main && git pull --ff-only && git fetch --prune`. Updates main locally so subsequent rebases (Phase 5) start from the new tip.

5. **Hard limit:** after 5 consecutive auto-merges, pause and ask the user "Continue with N more?" Reason: a misclassified PR shouldn't cause runaway merges; checking in every 5 lets the user catch a wrong gate decision before it compounds.

## Phase 5 — Branch convergence + cleanup (highest risk)

For each remaining local branch (skip the default branch). Process in this order:

### 5a. `[gone]` branches and locally-merged branches → delete

Use `scripts/safe-delete.sh <branch>` (add `--force-squashed` only for branches the audit flagged `squashed=true`). The script:
- Refuses if the branch is currently checked out in any worktree (`git worktree list` check)
- Uses `git branch -d` (lowercase, refuses unmerged work); `-D` only under `--force-squashed`, and only after re-confirming at exec time that `git cherry` shows no unique commits
- Reports the deleted commit hash so recovery is possible via `git reflog` or the safety tag

Read the exit code, don't just eyeball stdout: `0` = deleted, `2` = safety refusal (worktree blocking, or `git -d` judged the branch unmerged), `3` = dry-run echo, `1` = hard error (bad args, missing branch). An exit `2` on a branch you expected to be gone-and-merged is a signal to stop and look, not to reach for `-D`. If a worktree blocks deletion, ask the user: remove the worktree (`git worktree remove <path>`) or skip this branch?

### 5b. Behind/diverged branches → ask before merging main in

For each, ask the user: **rebase / merge main / skip**. Defaults to skip if no answer. If approved, run `scripts/try-merge.sh <branch> <strategy>`. The script:
- Switches to the branch, attempts `git merge main` (or `git rebase main`), and returns to the branch you started on when done
- **Clean result** (exit `0`) → commits (merge case) or completes (rebase case), pushes only if the branch has a live upstream (`--force-with-lease` for rebase)
- **rerere replayed a previously-recorded resolution** (exit `10`, `RERERE_RESOLVED`) → the same conflict the user already resolved once; committed and pushed. The script prints "rerere replayed cached resolutions" so the user knows to glance at the result.
- **Real conflict with no cached resolution** (exit `20`) → `git merge --abort` / `git rebase --abort`, leaves the branch exactly as it was, reports as blocked-by-conflict, moves on.
- **Push rejected** (exit `30`, `LEASE_FAILED`) → someone pushed in parallel; the local update stands but wasn't published. Report and let the user reconcile.

Push policy: the script pushes **only** when the branch has a configured upstream that still exists. A branch with no upstream is left updated locally (publishing it is the user's call); a branch whose upstream is `[gone]` is not resurrected. Both cases still return `0`/`10` — the update succeeded, it just wasn't pushed — and the script says which.

The skill **never** invokes `-X ours` or `-X theirs` automatically. That preference can lose data silently. If the user wants that, they can run it themselves after the skill completes.

Why merge before rebase as default? Merging is reversible (just delete the merge commit) while rebase rewrites the branch's history. Both achieve the same convergence; merge is safer when the skill is automating the choice.

### 5b′. `[gone]`-with-unique-work branches → ask, never auto-delete

A branch whose remote was deleted but that still has commits **not** in main (audit: `gone=true`, not merged, not squashed) is the dangerous case — the remote branch may have been deleted *before* the work merged, so deleting locally could be the last copy vanishing. The plan lists these separately under "Manual decisions". Ask per branch: delete anyway / keep / push somewhere. Never fold these into the 5a auto-delete batch.

### 5c. Stale-by-time branches → batch ask at the end

After all 5a/5b decisions, present the stale-by-time list (>3 months no commit) as a single batch question: "Delete these N branches (locally + remote where applicable)? (y/N)". Default no. List each branch with its last commit date and whether it has an open PR (skip those — they're handled in 5d).

### 5d. Branches with open PRs that aren't auto-mergeable

Don't touch. They remain as the user's working surface. Surface them in the final report so the user knows what's left.

### 5e. Working branches without PRs (currently checked out by user, ahead-of-main, no PR)

Don't touch. Mention in the final report.

### Final report

Re-run `audit.sh` and diff against the Phase 1 audit. Report:
- PRs merged (with URLs)
- Branches deleted (with prior commit hashes — for `git reflog` recovery)
- Branches still needing attention, with reason for each
- Safety tag name (so the user can revert if anything went sideways)

## Safety patterns enforced everywhere

| Rule | Enforcement |
|---|---|
| Never lose work | Phase 3 safety tag + `git branch -d` (safe form); `-D` only via `--force-squashed` with exec-time re-check |
| Never silent merge | Echo PR/branch/strategy before every `gh pr merge` and `git merge` |
| Never bypass hooks | No `--no-verify` anywhere in the skill or scripts |
| Never rewrite published history without lease | Force-push only via `--force-with-lease`, only after user approval per branch |
| Never publish what the user didn't | `try-merge.sh` pushes only to an existing upstream — never creates a remote branch or resurrects a `[gone]` one |
| Confirm destructive batches | 5-merge limit; batch ask for stale deletions; per-branch ask for behind/diverged strategy; separate ask for gone-with-work |
| Never trust a stale view | Fetch is verified (`FETCH_STATUS`); classifications are refused, not guessed, when it failed |
| Command-injection safe | Commit subjects reach the classifier as file data, never interpolated into shell source |
| Dry-run mode | Pass `DRYRUN=1` env to scripts → all `gh pr merge`, `git push`, `git branch -d`, `git rebase` become echoes |
| Worktree-aware | `safe-delete.sh` refuses if branch is checked out elsewhere; offers cleanup |
| Degrade loudly, not silently | No GitHub remote / no `gh` / unauthed → PR phases skipped with a named reason, local hygiene continues |
| Hard fail on dirty tree | Phase 1 checkpoint blocks branch-switching phases; offers commit / stash / abort |
| Re-verify gates at execute time | Phase 4 re-runs `gh pr view` immediately before each merge — state can change |

## Composition with other skills

| Skill | Relationship |
|---|---|
| `git-sync` | Use to find *which* repos need cleanup; then run `branch-cleanup` in each. The audit data shapes are intentionally compatible. |
| `commit-commands:clean_gone` | Equivalent to part of Phase 5a but slash-command only. This skill inlines the [gone]-detection so it can sequence with merges. |
| `commit-commands:commit-push-pr` | No overlap. That skill creates new PRs; this one reconciles existing ones. |
| `pr-workflow` | No overlap. Comment-thread replies. |
| `superpowers:finishing-a-development-branch` | Single-branch finalization. Runs after a feature; this skill runs across many branches. They can chain. |

## When NOT to use this skill

- Single-PR review or merge → use `gh pr merge` or `pr-review-toolkit:review-pr` directly.
- Resolving a known conflict you understand → just resolve it. This skill is for *bulk* convergence, not deep per-conflict work.
- Cleaning up across many repos → start with `git-sync` to triage, then run this in the worst-offender repos.
- Repos where main is protected by branch rules and you can't merge from CLI → the skill will detect and report; manual web UI merges are the right path.

## Failure modes to anticipate

| Symptom | Cause | What to do |
|---|---|---|
| PR bucketed `UNKNOWN_MERGEABILITY` | GitHub hasn't computed mergeability yet (recent push) | Re-query with `gh pr view` once before deciding; if still unknown, skip and report |
| `git merge --ff-only origin/main` fails | Main has diverged (rare; usually a force-push to main) | Stop the workflow. This is a manual investigation. |
| Worktree blocks branch delete | User has the branch checked out in another worktree | `safe-delete.sh` exits `2`; ask: remove worktree, or skip branch? |
| Rebase push rejected (`LEASE_FAILED`, exit 30) | Someone pushed to the branch in parallel | Local update stands but wasn't published; report, let user reconcile |
| `gh pr merge` fails with "review required" | Branch protection requires more reviewers than the PR has | Skip with reason; user must request more reviews |
| Default branch is not `main` (e.g. `master`, `develop`) | Detected via gh → remote `HEAD` → local `main`/`master` fallback chain | Scripts already resolve it; never hardcode `main` |
| `GH_STATE` degraded (no gh / unauthed / no GitHub remote) | Local-only repo, missing CLI, or not logged in | Run local phases; skip PR phases; name the reason to the user |
| `FETCH_STATUS=NO_REMOTE` | Repo has no configured remote at all | Not an error — do local branch hygiene only |
| Merge would leave the branch mid-conflict | rerere had no cached resolution | `try-merge.sh` aborts (exit 20), branch untouched — hand back to the user |
| Squash-merged branch reported "not fully merged" by `git -d` | Squash created a new SHA | Audit flags `squashed=true`; delete via `safe-delete.sh --force-squashed` |

## Output discipline

- Echo every destructive command before executing it (one line, prefixed with `→`)
- Show before-and-after summaries — the user should never have to re-audit to know what changed
- Use the safety tag name in the final report — recoverability is a feature, not a footnote
- For multi-step phases, print a phase header (e.g. `## Phase 4: Auto-merging 3 PRs`) so the chat log reads like an audit trail

## Edge cases worth memorizing

1. **Squash-merge already happened but local branch isn't deleted.** `git branch -d` says "not fully merged" because squash creates a new commit hash. The audit's `squashed=true` flag comes from `git cherry main <branch>` returning no `+` lines → all changes are in main. Delete via `safe-delete.sh --force-squashed`, which re-checks that property at exec time before using `-D`. Still worth a one-line confirm to the user, since `git cherry` can't distinguish "squash-merged" from "cherry-picked elsewhere".
2. **Branch tracks a renamed remote.** `git branch -vv` shows the old name with `[gone]`. Same handling as a deleted remote — delete locally.
3. **Tag named like a branch.** Use `refs/heads/<name>` explicitly when scripting deletes to avoid ambiguity.
4. **PR number reused after force-push.** `gh pr view N` will reflect the latest state. Always re-query at execute time, never trust the audit snapshot.
