# Git Worktree Removal (Never Attempt It Sandboxed)

> `git worktree remove` cannot succeed inside the sandbox, and it fails
> *destructively*. Run it unsandboxed on the FIRST attempt, never as a retry.
> Extends Golden Rule #11 in `~/.claude/CLAUDE.md`.

## Why this rule exists

`git worktree remove` must delete three things:

1. the worktree's working files      -> allowed (`~/code/**` is in `allowWrite`)
2. the worktree's `.git` file        -> **DENIED** (built-in `.git` protection)
3. `<main>/.git/worktrees/<name>/`   -> **DENIED** (same protection)

It does them in that order, so a sandboxed run **deletes every working file,
then aborts**. The result is a half-destroyed worktree.

This bit us on 2026-07-20 (svb-manager, PR #165 cleanup): the sandboxed attempt
wiped the working tree, the retry then refused with *"contains modified or
untracked files"* — and those "modified files" were **git's own partial
deletion**, not user work. The safety check that exists to stop you from
destroying uncommitted work had been turned into noise you clear with
`--force`. It was harmless only because the content had been verified as fully
merged beforehand.

**Widening the allowlist does not fix this.** `~/code/**` already covers the
denied paths; built-in denies win inside allowed regions (`denyWithinAllow`).
And the protection is worth keeping — write access to `.git/hooks` lets any
agent install a `pre-commit` hook that runs arbitrary code on every commit.

## The rule

1. **First attempt is unsandboxed.** Any `git worktree remove` (and `git
   worktree prune` / `git worktree add`, which touch the same admin dir) runs
   with `dangerouslyDisableSandbox: true` from the start. Never sandbox it,
   see it fail, then retry — the retry is already operating on wreckage.
2. **Verify before removing, not after.** Before deleting any worktree:
   - `git -C <wt> status --porcelain` is empty (no uncommitted work), and
   - `git -C <wt> diff origin/main <branch-tip> --stat` is empty (content
     really is on main; after a squash merge the *commits* will still show as
     unmerged — compare **content**, not commit ids).
   This check is what makes the operation recoverable. Do it first, every time.
3. **A half-deleted worktree means git's guard is unreliable.** If you see
   unstaged ` D ` entries you did not create, do NOT reach for `--force`
   reflexively. Re-run the step-2 content check against `origin/main` first;
   git can no longer tell you whether anything valuable is left.
4. **Squash merges need `git branch -D`.** `-d` will refuse because the commits
   were rewritten. That refusal is expected, not a warning about lost work —
   provided step 2 passed.
5. **Never remove a worktree you are standing in.** Drive it from the main
   checkout with `git -C <main-repo>`; the shell's cwd is deleted underneath it
   otherwise. Also leave *other* agents' worktrees alone (shared checkout).

## Pre-action check

*"Am I about to run a worktree command sandboxed — and have I proven the
content is on main, or am I trusting a guard the sandbox may already have
broken?"*
