---
name: findings-to-prs
description: Convert existing code-analysis or review findings into GitHub issues and verified draft PRs. Use after findings already exist when the user asks to continue with them, create issues and fixes, turn findings into PRs, fix review findings, says "mach mit den Findings weiter", or explicitly invokes findings-to-prs. Normalize findings, bundle related fixes, use isolated worktrees and harness-native subagents with fresh-context challenger review, open draft PRs, wait for CI, and repair CI failures without merging.
---

# Findings to Issues to verified Draft PRs

Take code-review findings that already exist in the current session or in a
findings file the user names and drive them through a five-phase pipeline:

```text
Phase 1: Normalize   findings -> .findings-to-prs/findings.json
Phase 2: Issues      one GitHub issue per finding + tracking issue (GATE: confirm count)
Phase 3: Bundle      group into reviewable units, skip protected paths
Phase 4: Fix         per bundle: worktree subagent -> failing test -> fix -> challenger
Phase 5: PR + CI     draft PR -> wait for CI checks -> fix failures -> final report
```

Never merge. Produce draft PRs plus a final report.

## Preconditions

1. Confirm findings exist in session context or in a user-named file. If not,
   stop without running a review implicitly.
2. Confirm `git rev-parse`, `gh auth status`, and a GitHub remote succeed.
   Determine the owner/repository with `gh repo view`.
3. Read the applicable project instruction files, including `AGENTS.md`,
   `CLAUDE.md`, and any rules they reference. Build the protected-path list from
   them: authentication boundaries, schema or migrations, deploy scripts,
   `.github/workflows/**`, `.env*`, secrets, and any project-specific additions.
   Never auto-fix protected paths. Create issues labeled
   `bot:skipped-needs-human` and exclude them from bundles.

## Phase 1 - Normalize findings

Write findings to `.findings-to-prs/findings.json` at the repository root and
ensure the directory is ignored by Git. Follow `references/schemas.md`. Require
a title, file and line, severity, description, evidence, and suggestion for
each finding. Put findings without a concrete location or evidence in
`skipped` with reason `not actionable`.

## Phase 2 - Create GitHub issues

Before creating anything, state how many issues will be created and get
confirmation unless the user's request already explicitly authorized creating
the issues. Issues are outward-facing.

- Create one issue per finding using `references/schemas.md`.
- Create missing workflow and severity labels; reuse equivalent existing labels.
- For protected paths, create the issue, add `bot:skipped-needs-human`, and
  comment with the required human decision.
- Create one tracking issue linking all created issues, grouped by bundle.
- Record issue numbers in `findings.json`.

If matching open issues already exist, adopt their numbers instead of creating
duplicates.

## Phase 3 - Bundle

Group fixable findings by the rule "one reviewer, one diff":

- Put the same root cause or shared helper in one bundle.
- Put overlapping files in the same bundle to prevent merge conflicts.
- Target fewer than about 400 changed lines per bundle; split larger work.
- Order security first, then value versus effort, with disjoint bundles first.
- Process at most six bundles by default; leave the rest in `backlog`.

Write the bundle plan into `findings.json` and present it briefly before fixing.
Continue without another pause only when the user authorized the full pipeline.

## Phase 4 - Fix each bundle

Process pending bundles. Use the harness-native subagent mechanism and isolated
worktrees when supported. Run disjoint bundles in parallel with at most two or
three workers; run overlapping bundles sequentially. If isolated subagents are
unavailable, create explicit worktrees and process bundles sequentially. Branch
each bundle from freshly fetched `origin/main`, checking the fetch exit code.

For every bundle, require the implementer to:

1. Create `fix/<bundle-id>-issue-<numbers>` from `origin/main`.
2. Write and capture a failing test for each finding before the fix. Exempt
   documentation-only findings.
3. Fix minimally, make bundle tests green, then run the full test and lint suite.
   Never weaken tests or checks to get green.
4. Return the branch name, diff summary, and test evidence.

Then run a fresh-context challenger using the harness-native challenger role
when available, otherwise a general subagent instructed to refute the fix. Give
it only the issue texts from `gh issue view` and `git diff origin/main`, not the
implementer's reasoning. After rejection, allow one repair and re-challenge.
After a second rejection, mark the bundle `failed`, preserve its branch, record
`failReason`, and continue.

If a fix unexpectedly needs a protected path, stop that bundle, mark it failed,
and do not modify the path.

## Phase 5 - Open draft PRs and verify CI

1. Push the branch and create a draft PR with `gh pr create --draft`. Include
   what and why, `Fixes #<n>` lines, test evidence, and challenger verdict.
2. Change issue labels to `bot:pr-open`; record bundle status and `prUrl`.
3. Run `scripts/wait-ci.sh <pr-number>`. Continue other independent bundles
   while CI runs, then collect results.
4. Repair red CI on the same branch, with at most two CI repair rounds per PR.
   Re-run the challenger when logic changes. If CI remains red, keep the PR in
   draft and report it.
5. Never mark PRs ready for review; the user controls review-bot quota timing.

## Final report

Report a table with bundle, issues, status, PR URL or failure reason, and CI
state. Include skipped issues and recommend the order for moving drafts to ready
one at a time. State failures plainly.

## Resources

- Read `references/schemas.md` for the JSON schema, issue template, labels,
  tracking issue, and challenger prompt.
- Run `scripts/wait-ci.sh` to poll GitHub PR checks.
