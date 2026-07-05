# Failing CI diagnosis reference

v1 scope: identify which job failed and surface a useful log excerpt. **Do not** attempt to fix failing tests — that's a separate skill (debugging, test-driven-development) and out of scope here.

## Why we surface this at all

When a PR is blocked by CI, the user has three options: fix the test, ignore the failure, or revert the breaking change. The skill can't decide which is right — but it can save the user 30 seconds of clicking into Actions logs by surfacing the failing job name and the relevant excerpt.

## How `audit.sh` finds failing CI

For each open PR, `gh pr list` returns `statusCheckRollup` — an array of every required check. We bucket each check:

| `conclusion` value | Meaning |
|---|---|
| `SUCCESS` | Passed |
| `FAILURE`, `CANCELLED`, `TIMED_OUT` | Failed → diagnosis target |
| `NEUTRAL`, `SKIPPED` | Treat as pass |
| `null` + `status` in `IN_PROGRESS`/`QUEUED`/`PENDING` | Still running — wait |

For PRs with at least one failure, we then call `gh run view <run-id> --log-failed` to get the failing job's log. The run ID is extracted from `detailsUrl` (last path segment).

## The log excerpt heuristic

CI logs are huge — 1000s of lines for a 30-line failure. v1 strategy:

1. Fetch the full log via `gh run view <run-id> --log-failed`
2. Scan for the first line containing one of: `error`, `fail`, `fatal`, `traceback` (case-insensitive)
3. Print 20 lines starting from 2 lines *before* that match (so the user sees the test name + the actual failure)

This is a heuristic — it'll miss some cases (e.g. compile errors that say "x is not defined" without the keyword "error"). v2 could:
- Use language-specific patterns (pytest's `FAILED test_name`, jest's `● Test:`, etc.)
- Search for the test runner's summary block
- Use the structured GitHub Actions annotation API (`gh api repos/<owner>/<repo>/check-runs/<id>/annotations`)

## What the skill does NOT do

- Does not download artifacts
- Does not parse coverage reports
- Does not retry failed runs (GitHub has its own UI for this; the skill's job is reporting, not re-triggering)
- Does not analyze test code or propose fixes
- Does not annotate the PR with comments

If the user wants any of those, they invoke a separate skill (`pr-review-toolkit:pr-test-analyzer`, `superpowers:systematic-debugging`).

## Output format in the audit

```
---PR_<number>_FAILING_CI---
---JOB:<job-name>---
<20 lines of log excerpt>
---JOB:<another-failing-job>---
<20 lines>
```

Capped at 3 jobs per PR (rare to have more relevant failures than that).

## Common failures by stack

For context-aware skills using `branch-cleanup`'s output:

| Stack | Common signature in log | Likely cause |
|---|---|---|
| TypeScript / Next.js | `TS2345`, `Type '...' is not assignable to type '...'` | Type drift from main |
| Vitest / Jest | `expected ... received ...`, `Test failed:` | Snapshot or behavior change |
| Python / pytest | `FAILED test_..::test_..`, `assert` lines | Logic or fixture drift |
| Convex deploy | `Schema validation failed`, `arg validator` | Schema change without migration |
| Vercel deploy | `Module not found`, `Build failed` | Missing env var or import |

These are out-of-scope for v1 to *act* on, but useful to surface in the report.

## Limit & timeout

`audit.sh` calls `gh run view --log-failed` with a 15-second timeout per job. If a fetch hangs or fails, we print `(could not fetch log)` and move on. The audit must always finish; never block on log fetching.
