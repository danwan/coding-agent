# PR verification reference

How to know with confidence that a PR is safe to auto-merge. Used by Phase 4.

## The three gates

A PR is auto-mergeable iff **all three** of:

1. **Mergeable without conflicts** — `mergeable == "MERGEABLE"`
2. **Approved** — `reviewDecision == "APPROVED"` (or `null` if no reviews are required by branch protection — treat as "ask user")
3. **All required checks green** — every entry in `statusCheckRollup` has `conclusion == "SUCCESS"` or is in a known-pass state

## The single command

```bash
gh pr view "$N" --json mergeable,mergeStateStatus,reviewDecision,statusCheckRollup,isDraft
```

`mergeStateStatus` is more granular than `mergeable` — possible values include:

| Value | Meaning |
|---|---|
| `CLEAN` | Mergeable, all checks pass, approved (best signal we have) |
| `BLOCKED` | Mergeable but blocked by branch protection (missing review, missing required check) |
| `BEHIND` | Behind base branch — needs update |
| `UNSTABLE` | Mergeable but checks are failing/pending |
| `DIRTY` | Has merge conflicts |
| `HAS_HOOKS` | Mergeable with passing hooks |
| `UNKNOWN` | GitHub hasn't computed yet — wait and retry once |

**Recommended check** (Bash):
```bash
state=$(gh pr view "$N" --json mergeStateStatus -q .mergeStateStatus)
if [[ "$state" == "CLEAN" || "$state" == "HAS_HOOKS" ]]; then
  # Safe to merge
fi
```

`CLEAN` is the cleanest signal. If you see `UNKNOWN`, GitHub is still computing — wait 10s and re-query once before giving up.

## Why re-verify at execute time

The audit (Phase 1) might be 30 seconds old. In that window:
- A teammate could have approved the PR (state changes from `BLOCKED` → `CLEAN`)
- A teammate could have pushed a commit (CI re-runs; `CLEAN` → `UNSTABLE`)
- A merge of another PR could have created a conflict (`CLEAN` → `DIRTY`)

Always re-query immediately before `gh pr merge`.

## Detecting the repo's allowed merge methods

Some repos disable specific merge methods via branch protection:

```bash
gh repo view --json mergeCommitAllowed,squashMergeAllowed,rebaseMergeAllowed
```

Returns three booleans. Pick the first allowed in this preference order: **squash → merge → rebase**. Squash gives the cleanest main history; rebase is the riskiest because it rewrites the PR's commits.

```bash
methods=$(gh repo view --json mergeCommitAllowed,squashMergeAllowed,rebaseMergeAllowed)
if echo "$methods" | jq -e '.squashMergeAllowed' >/dev/null; then
  METHOD="--squash"
elif echo "$methods" | jq -e '.mergeCommitAllowed' >/dev/null; then
  METHOD="--merge"
elif echo "$methods" | jq -e '.rebaseMergeAllowed' >/dev/null; then
  METHOD="--rebase"
else
  echo "No merge method allowed by repo settings — manual web UI merge required" >&2
fi
```

## The merge command

```bash
gh pr merge "$N" $METHOD --delete-branch
```

`--delete-branch` deletes the head branch on the remote after merge. The local branch tracking that ref will appear `[gone]` on the next `git fetch --prune` and gets cleaned up in Phase 5a.

## Common failure modes

| Error | Meaning | Skill response |
|---|---|---|
| `Pull request is not mergeable` | State changed since audit | Skip, log, move to "needs attention" |
| `Pull request is in clean status` (with --auto) | Auto-merge already armed | OK — just verify it merges as expected |
| `Pull request review process is not complete` | Required reviewers haven't approved | Skip, surface in report |
| `at least one approving review is required` | Branch protection requires review | Skip; user must request reviews |
| `Required status check ... is expected` | A required check hasn't run yet | Skip; re-run skill once CI completes |
| `403 — Resource not accessible by integration` | Token lacks `repo` scope | Hard fail; user must `gh auth refresh -s repo` |

## Avoid: `gh pr merge --auto`

`--auto` queues the merge to run *eventually* when gates pass. Tempting for "set and forget" but bad for this skill because:
- The skill loses control of ordering — auto-merges can fire while we're still doing local cleanup
- We can't sequence `git pull main` between merges (Phase 4 invariant)
- Failure modes are silent (auto-merge can be cancelled by a pushed commit)

Always merge synchronously and pull main between each merge.

## Squash-merge detection (post-merge)

After `gh pr merge --squash`, the local branch tracking that head will:
1. Have a remote that's `[gone]` (because of `--delete-branch`)
2. Show "not fully merged" if you run `git branch -d` (because the squash commit on main has a different SHA than the branch tip)

This is the **squashed** flag in audit.sh — `git cherry main <branch>` shows no `+` lines if the branch's contents are present in main, even via squash. Trust that signal; it's reliable for PRs merged via GitHub.
