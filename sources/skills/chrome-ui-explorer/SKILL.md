---
name: chrome-ui-explorer
description: Exploratory full-app UI testing of a web application through the user's real Chrome browser (Claude-in-Chrome extension), producing a unified run log and bug report. Use whenever the user asks to "test the UI", "click through the app", "run an exploratory test", "teste die App im Browser", "UI-Test", "alle Features durchtesten", or wants their app verified page by page and feature by feature — even if they don't explicitly say "test".
---

# Chrome UI Explorer

Exploratory QA of a web app through the user's real Chrome browser (Claude-in-Chrome). You act like a thorough manual tester: see everything, try everything, write everything down, never stop for a bug that isn't a total blocker.

**Not for:** deployed production apps with real user data, scripted/headless regression tests (use `webapp-testing`/Playwright), or anything that isn't a browser app.

Invoke the `claude-in-chrome` skill first if browser tools aren't loaded yet.

## Core loop: flush → act → capture

Console and network buffers accumulate across steps. Per-step attribution only works if you clear them — a plain read returns a snapshot and clears nothing, so pass `clear: true` (with the target `tabId`) on every read:

1. **Flush**: read console messages AND network requests with `clear: true`, discard the output. The buffers are now empty.
2. **Act**: one user action (click, type, submit, navigate).
3. **Capture**: read both again with `clear: true` and keep the output — everything in it was caused by this step, and the buffers are clean for the next one.

Never batch multiple actions between captures — you lose the ability to say *which* action caused *which* error.

**Credential redaction:** network captures include request bodies. Never copy the body of an auth/login request (or any captured credential/token) into `run.md` — record only method, path, and status for those.

## Screenshot policy

Screenshots return as inline base64 (~200KB each) and will blow up your context on a real app. Budget them:

- Text first: use `read_page`, `get_page_text`, and `find` for discovery and verification — they're cheap and usually sufficient.
- Screenshot only: (a) each *major* view once during discovery, (b) every failure/bug, (c) visual claims a text read can't support. Target ≤15 per run; if the app is bigger, say so in the report rather than silently shooting more.
- To persist one, use the screenshot tool's `save_to_disk` option, saving into `screenshots/NN-name.png`. If the installed extension version doesn't support it, reference evidence by step number in the log instead of file paths — never cite a file you didn't verify exists.

## Phase 0 — Setup

1. Create the run directory in the project: `test-runs/<YYYY-MM-DD-HHmm>/` with `run.md` (the unified log) and `screenshots/`.
2. Start the app if it isn't running (dev server, docker, whatever the project uses — check project docs/CLAUDE.md). Record the URL and start command in `run.md`.
3. **Find the app's own logs** — this matters for Phase 2's cross-check. Look for: server stdout (background task output), log files, a tracking/audit table, an analytics endpoint. Note in `run.md` where each lives and how to read it. If the app has none, note "no app-side logging" once and skip cross-checks later.
4. Open the app: `tabs_context_mcp`, then a new tab via `tabs_create_mcp`, navigate to the app URL.
5. **Log in.** Ask the user for credentials if none are known from the project (a `.env`, seed data, or the user's message). Never write credentials into `run.md` — write `<logged in as X>`.
6. First log entry: date, app URL, commit hash if in a git repo, browser tab id.

## Phase 1 — Discovery & inventory

Goal: a complete map before deep testing, so nothing is silently skipped.

1. Walk the primary navigation using text extraction (`read_page`/`get_page_text`). For every reachable page note its purpose and interactive elements (forms, buttons, menus, dialogs); screenshot only major views per the screenshot policy.
2. Open menus, dropdowns, modals, and settings panels far enough to inventory them.
3. **Termination:** keep a visited list keyed by URL/route; never re-crawl a visited view. For paginated or "load more" lists, inspect the first page plus one pagination action, then move on. Cap discovery at depth 3 from the main nav — log anything deeper as `not explored`.
4. Build the **feature inventory** in `run.md`: a checklist table — `| # | View/Feature | What it should do | Status |` — with status `pending` for all. This table is the contract for Phase 2: every row gets tested or gets an explicit skip reason.

## Phase 2 — Feature test loop

Work through the inventory row by row. For each feature:

1. Decide the expectation *before* acting: what should happen on success? Write it down first.
2. Run the flush→act→capture loop for each step. Exercise it properly: create real entries, fill forms with valid data, save configurations, use every option — including edit and delete of what you created. Also try one obvious invalid input per form and check the app handles it gracefully.
3. Verify the outcome in the UI via text extraction (did the entry appear? did the setting persist?).
4. **Cross-check the app's own logs**: read the app-side log/tracking source from Phase 0 and confirm your action was recorded correctly (right event, right data, right user). Correlate by the entity id or timestamp of this step, not by "latest line". Mismatches are bugs.
5. Update the inventory row: `pass`, `fail`, or `partial`, linking to the log entry.

### Per-step log entry format in `run.md`

```markdown
### Step 12 — Create project via "New Project" dialog
- Expectation: project appears in list, POST /api/projects returns 201
- Action: filled name "Testprojekt QA", clicked Save
- Result: PASS
- Evidence: console: clean · network: POST /api/projects 201 (screenshot 12 if taken)
- App log: `project.created id=42 user=danny` ✓ matches
```

For failures add `- Bug: BUG-03` linking into the bug list, plus the exact console error / failed request.

## Phase 3 — Resilience rules

- **A bug is never a reason to stop.** Document it (evidence, app log state, repro steps), mark the inventory row `fail`, move to the next feature.
- **Session expiry**: if a page unexpectedly shows the login screen or redirects to login, that is not a bug — re-authenticate, retry the step once, and note the re-login in the log.
- **Crash / blank page / frozen UI**: capture the broken state first, then reload the tab. If reload doesn't recover, navigate to the app root. Log the recovery path.
- **Total blocker only** (app won't start, login impossible, every page errors): stop, write up what you tried, report to the user. Everything less than that: continue.
- **Irreversible side effects**: only delete/reset entries *you created in this run*. Skip anything that fires external or irreversible effects — real emails, webhooks, payments, notifications to third parties, global config resets — unless the user has confirmed this is a safe/sandboxed environment. Log each as `skipped — external/irreversible side effect`.
- If browser tools stop responding (likely a native dialog), tell the user to dismiss it — don't retry blindly.

## Phase 4 — Report

Finish `run.md` with:

```markdown
## Summary
- Tested: X of Y features · pass A · fail B · partial C · skipped D (reasons)
- App-log cross-check: E of F actions correctly tracked

## Bugs
### BUG-01 — <one-line title> (severity: blocker/major/minor)
- Where: <view / feature>
- Repro: <numbered steps>
- Expected / Actual:
- Evidence: console error · failed request · screenshot/step ref · app-log mismatch

## Not covered
<anything skipped and why — silent gaps are worse than reported gaps>
```

Severity guide: **blocker** = feature unusable, **major** = wrong behavior/data, **minor** = cosmetic or edge-case. End your reply to the user with the summary table and the path to `run.md`.
