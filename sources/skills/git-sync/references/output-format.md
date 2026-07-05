# git-sync.sh Output Format

## Audit output structure per repo

A `NOTE=...` line may precede all repo blocks (e.g. when the target directory
is itself a git repo — it is not audited, only its subdirectories).

```
===REPO_START=== <name>
BRANCH=<branch|DETACHED>
REMOTE_URL=<url|NONE>
FETCH=<OK|FAILED|SKIPPED>        SKIPPED = no remote, or audit ran with --no-fetch
LOCAL_BRANCHES=<n>
REMOTE_BRANCHES=<n>
STAGED=<n>
UNSTAGED=<n>
UNTRACKED=<n>
AHEAD=<n>
BEHIND=<n>
DIVERGED=<YES|NO|UNKNOWN>
STASH=<n>
WORKTREE=<CLEAN|DIRTY>
TRACKING_START
<branch> <upstream> [ahead N] [behind N] | [gone] | [no upstream]
TRACKING_END
UNTRACKED_FILES_START   (only if UNTRACKED > 0)
<file paths>
UNTRACKED_FILES_END
REMOTE_ONLY=<n>
REMOTE_ONLY_START       (only if REMOTE_ONLY > 0)
<remote-branch>|<date>|<commit-subject>|<relationship>|<+N/-M>|<based_on:ref>
REMOTE_ONLY_END
OPEN_PRS=<n|UNAVAILABLE>
OPEN_PRS_START          (only if OPEN_PRS > 0)
#<number>|<title>|<branch>|<date>
OPEN_PRS_END
===REPO_END===
```

## REMOTE_ONLY fields (pipe-separated per line)

1. **Branch name** — full remote branch name (e.g., `origin/feature-x`)
2. **Last commit date** — YYYY-MM-DD
3. **Last commit message** — subject line
4. **Relationship** — compared against the REMOTE default branch
   (`origin/HEAD`, falling back to `origin/main`/`origin/master`), so a stale
   local main does not skew classification. One of:
   - `AHEAD_OF_MAIN` — builds on current remote default HEAD
   - `BEHIND_MAIN` — based on older main, no own commits
   - `DIVERGED_FROM_MAIN` — has own commits AND main moved ahead
   - `SAME_AS_MAIN` — identical to main (no delta)
   - `BASED_ON:<local-branch>` — based on a local feature branch that is NOT
     already merged into the default branch
   - `UNKNOWN` — could not determine (e.g., no default branch)
5. **Diff stat** — `+N/-M` lines vs merge-base
6. **Base info** — `based_on:<commit-ref>` or `based_on:<branch-name>`

## OPEN_PRS fields (pipe-separated per line)

1. **PR number** — e.g., `#42`
2. **Title** — PR title
3. **Branch** — head ref name
4. **Updated** — YYYY-MM-DD last update date

## Action command output

`===ACTION=== <cmd> <repo>` followed by `RESULT=OK|FAILED|SKIPPED` and `MESSAGE=...`
(SKIPPED currently only from `fetch-all` for repos without a remote.)
