#!/usr/bin/env bash
# plan.sh — Phase 2 of branch-cleanup skill.
# Usage: plan.sh [audit-output-file]
#   With an argument: reads a saved audit.sh output (avoids running the audit —
#   and its fetch + CI-log calls — a second time).
#   Without: runs audit.sh itself.
# Writes a markdown plan to a temp file and echoes the path on the last line.
# The plan body is also printed for the caller to display directly.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TMPDIR_RESOLVED="${TMPDIR:-/tmp}"

AUDIT_FILE="${1:-}"
if [[ -n "$AUDIT_FILE" ]]; then
  if [[ ! -r "$AUDIT_FILE" ]]; then
    echo "ERROR: audit file not readable: $AUDIT_FILE" >&2
    exit 1
  fi
  if ! grep -q '^===AUDIT_START===' "$AUDIT_FILE"; then
    echo "ERROR: $AUDIT_FILE does not look like audit.sh output" >&2
    exit 1
  fi
else
  AUDIT_FILE="${TMPDIR_RESOLVED%/}/branch-cleanup-audit-$$.txt"
  bash "$SCRIPT_DIR/audit.sh" > "$AUDIT_FILE"
  trap 'rm -f "$AUDIT_FILE"' EXIT
fi

REPO_NAME=$(grep '^REPO_NAME=' "$AUDIT_FILE" | head -1 | cut -d= -f2-)
TS=$(date +%s)
PLAN_FILE="${TMPDIR_RESOLVED%/}/branch-cleanup-${REPO_NAME:-repo}-${TS}.md"

# Classify in Python. The audit text is passed as a FILE, never interpolated
# into the script source — commit subjects can contain quotes, backslashes,
# $(), backticks, and pipes without breaking anything.
python3 - "$AUDIT_FILE" "$PLAN_FILE" <<'PYEOF'
import sys
from datetime import datetime

with open(sys.argv[1]) as f:
    audit = f.read()
plan_path = sys.argv[2]

def kv_block(text, name):
    """Extract lines between NAME_START / NAME_END."""
    start, end = f"{name}_START", f"{name}_END"
    in_block, out = False, []
    for line in text.splitlines():
        if line.strip() == start:
            in_block = True; continue
        if line.strip() == end:
            in_block = False; continue
        if in_block:
            out.append(line)
    return out

def parse_pipe(line):
    """Parse 'PREFIX|k1=v1|k2=v2|...' into a dict (skipping the prefix token).
    A field without '=' is glued onto the previous field — commit subjects
    may contain literal '|' characters and the subject is the last field."""
    parts = line.split("|")
    d, last_key = {}, None
    for p in parts[1:]:
        if "=" in p:
            k, v = p.split("=", 1)
            d[k] = v
            last_key = k
        elif last_key:
            d[last_key] += "|" + p
    return d

import re
kv = {}
for line in audit.splitlines():
    if "=" in line and not line.startswith(("BRANCH|","PR|","REMOTE_ONLY|","---")):
        m = re.match(r'^([A-Z_][A-Z0-9_]*)=(.*)$', line)
        if m:
            kv[m.group(1)] = m.group(2)

default_branch = kv.get("DEFAULT_BRANCH", "main")
worktree = kv.get("WORKTREE", "?")
main_state = kv.get("MAIN_STATE", "?")
current = kv.get("CURRENT_BRANCH", "?")
fetch_status = kv.get("FETCH_STATUS", "?")
gh_state = kv.get("GH_STATE", "?")

branches = [parse_pipe(l) for l in kv_block(audit, "BRANCHES") if l.startswith("BRANCH|")]
remotes = [parse_pipe(l) for l in kv_block(audit, "REMOTE_ONLY") if l.startswith("REMOTE_ONLY|")]
prs = [parse_pipe(l) for l in kv_block(audit, "PRS") if l.startswith("PR|")]
worktrees = [l for l in kv_block(audit, "WORKTREES") if l.strip()]

# Bucket PRs
auto_merge = [p for p in prs if p.get("cat") == "MERGEABLE_GREEN"]
mergeable_no_review = [p for p in prs if p.get("cat") == "MERGEABLE_NO_REVIEW"]
blocked_conflict = [p for p in prs if p.get("cat") == "BLOCKED_CONFLICT"]
blocked_ci = [p for p in prs if p.get("cat") == "BLOCKED_CI"]
pending_ci = [p for p in prs if p.get("cat") == "PENDING_CI"]
blocked_review = [p for p in prs if p.get("cat") == "BLOCKED_REVIEW"]
draft = [p for p in prs if p.get("cat") == "DRAFT"]
unknown_merge = [p for p in prs if p.get("cat") == "UNKNOWN_MERGEABILITY"]

# Branches with active PRs (don't auto-clean these)
pr_branches = {p.get("head") for p in prs}

# Bucket branches — MUTUALLY EXCLUSIVE, priority order:
#   cleanup (gone-safe / merged / squashed)  >  gone-with-unique-work (manual)
#   >  stale (batch ask)  >  behind/diverged (per-branch ask)
# Without this priority a [gone] or squashed branch would ALSO show up in the
# "diverged — will ask" list and the user gets asked twice about the same branch.
def is_cleanup_safe(b):
    return b.get("class") == "MERGED_INTO_DEFAULT" or b.get("squashed") == "true"

nondefault = [b for b in branches if b.get("class") != "DEFAULT"]
gone_all = [b for b in nondefault if b.get("gone") == "true"]
gone_safe = [b for b in gone_all if is_cleanup_safe(b)]
gone_unmerged = [b for b in gone_all if not is_cleanup_safe(b)]
merged = [b for b in nondefault if b.get("class") == "MERGED_INTO_DEFAULT" and b.get("gone") != "true"]
squashed = [b for b in nondefault if b.get("squashed") == "true" and b.get("gone") != "true"
            and b.get("class") != "MERGED_INTO_DEFAULT"]
handled = {b.get("name") for b in gone_all} | {b.get("name") for b in merged} | {b.get("name") for b in squashed}
stale = [b for b in nondefault if b.get("stale") == "true"
         and b.get("name") not in handled and b.get("name") not in pr_branches]
handled |= {b.get("name") for b in stale}
behind = [b for b in nondefault if b.get("class","").startswith("BEHIND_DEFAULT")
          and b.get("name") not in handled]
diverged = [b for b in nondefault if b.get("class","").startswith("DIVERGED_FROM_DEFAULT")
            and b.get("name") not in handled]
ahead = [b for b in nondefault if b.get("class","").startswith("AHEAD_OF_DEFAULT")
         and b.get("name") not in handled]

def b_link(b):
    return b.get("name", "?")

lines = []
lines.append(f"# Branch Cleanup Plan — {kv.get('REPO_NAME','?')}")
lines.append("")
lines.append(f"_Generated {datetime.now().isoformat(timespec='seconds')}_  ")
lines.append(f"Default branch: `{default_branch}`  ·  Current: `{current}`  ·  Working tree: **{worktree}**  ·  main vs origin: `{main_state}`")
lines.append("")

# Hard blocker: stale remote view. Every classification below may be wrong.
if fetch_status not in ("OK", "NO_REMOTE"):
    lines.append("## ⛔ Fetch failed — remote view is STALE, do not trust this plan")
    lines.append("")
    lines.append(f"`FETCH_STATUS={fetch_status}`")
    lines.append("Fix the fetch (network/auth/sandbox), re-run the audit, regenerate the plan.")
    lines.append("")

# Hard blocker: dirty tree
if worktree == "DIRTY":
    lines.append("## ⛔ Working tree is dirty — STOP")
    lines.append("")
    lines.append(f"Staged: {kv.get('STAGED','?')}, unstaged: {kv.get('UNSTAGED','?')}, untracked: {kv.get('UNTRACKED','?')}.")
    lines.append("Commit or stash before running cleanup (the skill can stash for you if you approve).")
    lines.append("")

# Degraded mode: no PR data
if gh_state not in ("OK", "?"):
    reasons = {
        "NO_GH_CLI": "`gh` CLI is not installed",
        "NO_GITHUB_REMOTE": "this repo has no GitHub remote",
        "NOT_AUTHENTICATED": "`gh` is not authenticated (run `gh auth login`)",
        "ERROR": f"gh failed: {kv.get('GH_ERROR','unknown error')}",
    }
    lines.append(f"## ⚠️ PR phases skipped — {reasons.get(gh_state, gh_state)}")
    lines.append("")
    lines.append("Local branch hygiene (Phases 3 + 5) still applies; Phase 4 (PR auto-merge) does not.")
    lines.append("")

if kv.get("PR_TRUNCATED") == "true":
    lines.append(f"> ⚠️ Only the first {kv.get('PR_COUNT','100')} open PRs were fetched — more exist. Re-run after this batch.")
    lines.append("")

# Section 1: auto-merges
lines.append("## 1. Auto-merges (will execute without asking, after re-verifying gates)")
lines.append("")
if auto_merge:
    lines.append("| # | PR | Branch | Title |")
    lines.append("|---|----|--------|-------|")
    for p in auto_merge:
        lines.append(f"| | #{p.get('number','?')} | `{p.get('head','?')}` | {p.get('title','')} |")
else:
    lines.append("_None._")
if mergeable_no_review:
    lines.append("")
    lines.append("**Approvable but no review yet (will ask):**")
    for p in mergeable_no_review:
        lines.append(f"- #{p.get('number','?')} `{p.get('head','?')}` — {p.get('title','')}")
lines.append("")

# Section 2: manual decisions
lines.append("## 2. Manual decisions (will ask each)")
lines.append("")
if unknown_merge:
    lines.append("**Mergeability unknown (GitHub still computing — re-query before deciding):**")
    for p in unknown_merge:
        lines.append(f"- #{p.get('number','?')} `{p.get('head','?')}` — {p.get('title','')}")
    lines.append("")
if blocked_conflict:
    lines.append("**Blocked by conflicts — will not auto-resolve:**")
    for p in blocked_conflict:
        lines.append(f"- #{p.get('number','?')} `{p.get('head','?')}` — {p.get('title','')}")
    lines.append("")
if blocked_ci:
    lines.append("**Blocked by failing CI — see audit log excerpts:**")
    for p in blocked_ci:
        lines.append(f"- #{p.get('number','?')} `{p.get('head','?')}` failing: {p.get('failing','-')} — {p.get('title','')}")
    lines.append("")
if pending_ci:
    lines.append("**CI pending (will skip — re-run skill once green):**")
    for p in pending_ci:
        lines.append(f"- #{p.get('number','?')} `{p.get('head','?')}`")
    lines.append("")
if blocked_review:
    lines.append("**Awaiting review:**")
    for p in blocked_review:
        lines.append(f"- #{p.get('number','?')} `{p.get('head','?')}` review={p.get('review','?')} — {p.get('title','')}")
    lines.append("")
if draft:
    lines.append("**Draft PRs (left alone):**")
    for p in draft:
        lines.append(f"- #{p.get('number','?')} `{p.get('head','?')}` — {p.get('title','')}")
    lines.append("")
if gone_unmerged:
    lines.append("**Remote branch deleted but local has unique commits (will ask: delete anyway / keep / push elsewhere):**")
    for b in gone_unmerged:
        lines.append(f"- `{b_link(b)}` ({b.get('class','?')}, was tracking `{b.get('upstream','?')}`) — work may never have been merged")
    lines.append("")
if behind:
    lines.append("**Behind-main local branches (will ask: rebase / merge main / skip):**")
    for b in behind:
        has_pr = b.get("name") in pr_branches
        lines.append(f"- `{b_link(b)}` ({b.get('class','?')}, last commit {b.get('age_days','?')} days ago){' — has open PR' if has_pr else ''}")
    lines.append("")
if diverged:
    lines.append("**Diverged from main (will ask: rebase / merge main / skip):**")
    for b in diverged:
        has_pr = b.get("name") in pr_branches
        lines.append(f"- `{b_link(b)}` ({b.get('class','?')}){' — has open PR' if has_pr else ''}")
    lines.append("")

# Section 3: cleanup
lines.append("## 3. Cleanup (after main is up-to-date in Phase 3)")
lines.append("")
if gone_safe:
    lines.append("**[gone] tracking refs, content in main (will delete locally — remote already gone):**")
    for b in gone_safe:
        lines.append(f"- `{b_link(b)}` (was tracking `{b.get('upstream','?')}`)")
    lines.append("")
if merged:
    lines.append("**Merged into default (safe to delete):**")
    for b in merged:
        if b.get("name") in pr_branches:
            continue  # skip if there's still an open PR (rare but possible)
        lines.append(f"- `{b_link(b)}`")
    lines.append("")
if squashed:
    lines.append("**Likely squash-merged (will ask before `-D`):**")
    for b in squashed:
        lines.append(f"- `{b_link(b)}` — `git cherry` shows no unique commits vs default")
    lines.append("")
if stale:
    lines.append("**Stale by time (will batch-ask):**")
    for b in stale:
        lines.append(f"- `{b_link(b)}` (last commit {b.get('age_days','?')} days ago, {b.get('class','?')})")
    lines.append("")
if remotes:
    lines.append("**Remote-only branches (no local copy — left as-is, listed for visibility):**")
    for r in remotes[:20]:
        lines.append(f"- `origin/{r.get('name','?')}` ({r.get('age','?')})")
    if len(remotes) > 20:
        lines.append(f"- … and {len(remotes)-20} more")
    lines.append("")
if worktrees:
    lines.append("**Worktrees (skill will refuse to delete a branch checked out in a worktree):**")
    for w in worktrees:
        lines.append(f"- `{w}`")
    lines.append("")

# Section 4: order
lines.append("## 4. Execution order")
lines.append("")
lines.append("1. **Phase 3** — Tag safety, fast-forward main, push if ahead, enable rerere (+autoupdate).")
n = 2
if auto_merge:
    lines.append(f"{n}. **Phase 4** — Auto-merge {len(auto_merge)} PR(s), pulling main between each.")
    n += 1
ask_branches = [b for b in behind + diverged if b.get("name") not in pr_branches]
if ask_branches or gone_unmerged:
    lines.append(f"{n}. **Phase 5b** — For {len(ask_branches)} branch(es), ask rebase/merge/skip"
                 + (f"; decide {len(gone_unmerged)} [gone]-with-unique-work branch(es)" if gone_unmerged else "") + ".")
    n += 1
if gone_safe or merged or squashed:
    lines.append(f"{n}. **Phase 5a** — Delete {len(gone_safe)+len(merged)} merged/[gone] branches.")
    if squashed:
        lines.append(f"   - Ask before deleting {len(squashed)} squash-merged branch(es).")
    n += 1
if stale:
    lines.append(f"{n}. **Phase 5c** — Batch-ask about {len(stale)} stale branch(es).")
    n += 1
lines.append(f"{n}. **Final report** — Re-audit, show before/after.")
lines.append("")

lines.append("---")
lines.append("")
lines.append("To proceed: reply **approve**, **amend** (then edit this file), or **abort**.")

content = "\n".join(lines)
with open(plan_path, "w") as f:
    f.write(content)

print(content)
print()
print(f"PLAN_FILE={plan_path}")
PYEOF
