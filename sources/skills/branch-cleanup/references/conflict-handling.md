# Conflict handling reference

The skill takes a conservative stance on merge conflicts: never silently pick a side. Used by `try-merge.sh` and Phase 5b decisions.

## The hierarchy of conflict outcomes

When `git merge` or `git rebase` encounters a conflict, four things can happen:

1. **No conflict** — Git auto-merges. We commit and push.
2. **rerere replays a cached resolution** — Git applies a previous resolution recorded for the *exact same conflict hunk*. This is safe because the user has already seen and approved this resolution before. We commit and push, marking the result as "non-overlapping".
3. **Trivial structural conflict** — e.g. both sides added different code to a file, but in regions that don't overlap. Git will mark this as a conflict even though there's no semantic overlap. The skill **does not** auto-resolve these in v1 — too many false positives where syntactic non-overlap masks real semantic overlap (e.g. both sides import the same thing differently).
4. **Real overlap** — Same lines edited differently on both sides. The skill aborts and reports.

## Why `git rerere` is on by default

`git config rerere.enabled true` (set in Phase 3) tells Git to:
- Record how you resolve a conflict the first time
- Replay that resolution automatically the next time the *exact same conflict* appears

This pays off for repeated rebases against a moving main:
- Day 1: Rebase feature-X onto main, resolve a conflict in `app/api/users.ts`
- Day 2: Main has moved, rebase again, *same conflict* — rerere replays your fix automatically

It's safe because:
- Resolutions are exact-match (same conflict markers, same context)
- Replays only happen for conflicts the user has resolved before
- The replay is committed as a normal commit; the user can `git diff HEAD~1` to verify

It's idempotent — re-enabling on a repo that already has it set is a no-op.

## Why we don't use `-X ours` or `-X theirs`

Both options auto-resolve conflicts in favor of one side. They're often suggested as "just make the merge work" — but they silently lose data:

- `-X ours` keeps your side, **discards** the other side's edits in conflicting hunks. Non-conflicting changes from the other side still come through.
- `-X theirs` is the inverse.

The skill never invokes these. If the user wants this behavior, they should run it themselves *after* seeing the conflict — that way they've consciously decided to discard data.

There is a worse strategy: `git merge -s ours <branch>` (note: strategy, not -X option). This pretends the merge happened without taking *any* changes from the other branch. **Never use this.** It's almost always a mistake.

## What `try-merge.sh` actually does on conflict

Pseudo-code:

```
git config rerere.enabled true
git config rerere.autoupdate true      # <-- staging is what makes the check below work
git merge default
if exit == 0:
  push (if upstream exists) and exit CLEAN=0
else:
  unmerged = git ls-files -u | wc -l
  if unmerged == 0:
    # rerere replayed a cached resolution AND autoupdate staged it →
    # the index is clean, so we can finish the merge/rebase.
    git commit --no-edit          (or GIT_EDITOR=true git rebase --continue)
    push (if upstream exists) and exit RERERE_RESOLVED=10
  else:
    # unresolved conflicts we won't guess at
    git merge --abort             (or git rebase --abort)
    exit REAL_CONFLICT=20         → user handles this themselves
```

**Why `rerere.autoupdate` is not optional here.** With rerere enabled but autoupdate *off*, a replayed resolution is written to the working tree but the conflicted stages stay in the index — `git ls-files -u` still reports unmerged paths. The `unmerged == 0` branch would never fire, and every rerere-resolvable merge would be needlessly aborted as a "real conflict". Turning autoupdate on stages the replayed resolution, so a fully-replayed conflict leaves zero unmerged paths and the merge completes. Phase 3 sets both configs for exactly this reason.

On a real conflict the branch is left exactly as it was before the attempt (aborted), and `try-merge.sh` switches back to whatever branch you started on. Recovery is unnecessary.

## Recovery: if a merge or rebase landed somewhere weird

The Phase 3 safety tag plus reflog means you can always recover:

```bash
# Find the original SHA
git reflog show <branch> | head -10

# Restore to a specific reflog entry
git switch <branch>
git reset --hard <branch>@{2}      # 2 reflog entries ago

# Or from the safety tag (HEAD before skill started)
git reset --hard claude-cleanup-backup-<ts>
```

`git reset --hard` is destructive of the working tree, so commit/stash anything first. The skill never invokes `--hard` reset; this is a manual recovery tool.

## Edge case: rebase with rerere ate every conflict but result is wrong

This is rare but possible if the user resolved a conflict carelessly the first time and rerere is now replaying that careless resolution. Mitigations:

- Phase 5b only runs `try-merge.sh` after the user picked rebase/merge for that branch — so the user is engaged
- The skill prints "rerere replayed cached resolutions" so the user knows to look
- After push, `git log <branch>` shows the result; `git diff HEAD~1` shows what was applied

Auto-resolution by rerere does not skip user awareness — it just skips the manual conflict marker editing.

## When in doubt, abort and ask

The conservative path is always cheap. Aborting a merge (`git merge --abort`) and asking the user "this branch has overlapping conflicts, would you like me to skip it?" is much cheaper than a silent bad merge that hits main.

The skill defaults to abort+ask whenever it can't be 100% sure the result is what the user wants.
