# Schemas and templates

## findings.json

Store this file at `.findings-to-prs/findings.json` in the repository root and
keep the directory ignored by Git.

```json
{
  "createdAt": "<ISO date>",
  "repo": "<owner/name>",
  "maxBundlesPerRun": 6,
  "findings": [
    {
      "id": "F1",
      "title": "<one-line defect statement>",
      "file": "path/to/file.ts:123",
      "severity": "critical|high|medium|low",
      "description": "<what is wrong and why it matters>",
      "evidence": "<code excerpt or verified reasoning>",
      "suggestion": "<concrete fix shape>",
      "issue": 247,
      "protectedPath": false
    }
  ],
  "bundles": [
    {
      "id": "B1",
      "title": "<PR-ready title>",
      "findingIds": ["F1", "F2"],
      "issues": [247, 248],
      "files": ["src/members.ts"],
      "rationale": "<why bundled, 1-2 sentences>",
      "testPlan": "<which failing test proves each finding>",
      "estSize": "S|M|L",
      "order": 1,
      "status": "pending|backlog|in_progress|done|failed",
      "branch": "fix/B1-issue-247-248",
      "prUrl": null,
      "failReason": null,
      "ci": "pending|green|red|timeout"
    }
  ],
  "skipped": [
    {
      "findingId": "F9",
      "issue": 251,
      "reason": "<protected path / not actionable / needs decision>"
    }
  ]
}
```

## Issue body template

```markdown
**Source:** <analysis name/date> - **Severity:** <severity> - **Location:** `<file:line>`

## Description
<description>

## Evidence
<evidence>

## Suggested fix
<suggestion>
```

Use title `[<SEVERITY>] <finding title>`. Match the project's language.

## Labels

Create missing labels idempotently and reuse existing labels with equivalent
meaning.

| Label | Color | Purpose |
| --- | --- | --- |
| `bot:queued` | `0e8a16` | Fixable and in the current plan |
| `bot:in-progress` | `fbca04` | Currently being fixed |
| `bot:pr-open` | `1d76db` | Draft PR open |
| `bot:skipped-needs-human` | `d93f0b` | Requires a human decision |
| `severity-high` | `b60205` | High severity |
| `severity-medium` | `fbca04` | Medium severity |
| `severity-low` | `c2e0c6` | Low severity |

Optionally add one run label such as `review-<YYYY-MM>`.

## Tracking issue

Use title `Tracking: <analysis name> (<N> findings)`. Group its checklist by
bundle, then list skipped issues with reasons. Add PR links as drafts open.

## Challenger prompt

```text
You are a skeptical reviewer with no prior context. Given only the issue texts
and this diff, try to refute the fix. Check whether the diff resolves every
issue, introduces regressions, proves the behavior with tests that would fail
without the fix, or touches anything the issues do not justify. Return a verdict
per issue: resolved, not resolved, or uncertain, with reasons. Reject the whole
bundle if any test is cosmetic.
```

## Hard rules

- Never merge, force-push, or commit to the default branch.
- Never weaken tests or checks to get green; use at most five commits per PR.
- Never modify protected paths identified from the applicable project
  instruction files; create `bot:skipped-needs-human` issues instead.
- Open draft PRs only. The user moves them to ready one at a time.
