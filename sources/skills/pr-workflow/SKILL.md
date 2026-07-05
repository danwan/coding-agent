---
name: pr-workflow
description: GitHub PR review comment replies via CLI. Use when replying to PR review comments.
allowed-tools: Bash, Read
version: 1.0.0
effort: low
---

# GitHub PR Review Comment Replies

Reply to PR review comments via CLI using `in_reply_to` on the comments endpoint.

## Usage

```bash
# List comment IDs for a PR
gh api repos/{owner}/{repo}/pulls/{PR}/comments --jq '.[].id'

# Reply to a specific comment
gh api repos/{owner}/{repo}/pulls/{PR}/comments \
  -f body="Reply text" \
  -F in_reply_to={COMMENT_ID}
```

## Pitfalls

- The `/pulls/comments/{id}/replies` sub-endpoint returns **404** — always use the main comments endpoint with `in_reply_to`
- `gh api` calls require `dangerouslyDisableSandbox: true` (TLS cert verification fails in sandbox)
