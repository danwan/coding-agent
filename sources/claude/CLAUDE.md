# Global Operating Rules

These rules apply globally, to every project on this machine, unless a project CLAUDE.md overrides them.
Bias: caution over speed on non-trivial work. Use judgment on trivial tasks.

> **Scope of this file.** It carries what the model cannot derive: this machine's
> state, account and quota realities, project conventions, and the boundaries of
> destructive actions. It deliberately does NOT restate general good practice.
> Current models verify their own work, keep scope, and report honestly without
> being told; instructions that repeat those cause over-verification and longer
> output rather than better work. Before adding a rule here, ask whether a
> capable model would already do it unprompted — if yes, it does not belong.

## Working Rules

1. **Bug fix → failing test first.** Write a test that reproduces the bug and fails, then make it pass. For a feature, name one observable check that proves it works.
2. **Surface conflicts, don't average them.** If two patterns contradict, pick one (more recent / more tested), say why, flag the other for cleanup.
3. **If code can answer, code answers.** Deterministic transforms, bulk edits, counting → write a script instead of doing it "by hand" across files.

## Delegating to subagents

Subagents multiply cost and latency: each one re-establishes context, re-explores, and reports back, and you then re-read its report.

- **Do NOT delegate review, verification, or double-checking.** Verification belongs in the main loop.
- **Do NOT delegate** work you could finish yourself in a handful of tool calls.
- **Do delegate** genuinely independent, sizeable tracks — a wide multi-file investigation, unrelated modules, a fan-out across many items.
- Prefer one subagent over several. Keep spawn counts low; a normal task needs zero or one.
- Brief precisely the first time. Once a subagent reports, commit to its result — do not re-derive its findings.

Opus 5 reaches for subagents readily and needs this ceiling. Fable 5 is the
opposite: it sustains long-running parallel delegation reliably, so on Fable 5
delegate freely and asynchronously rather than applying the cap above.

## Golden Rules (project-agnostic things that often go wrong)

1. **Python → UV** (when applicable): deps in `.venv` via uv. `uv run …`.
2. **Git → HTTPS to github.com** via the `gh` credential helper, all git via CLI. A global `url."https://github.com/".insteadOf "git@github.com:"` rewrites SSH remotes → HTTPS at runtime, so `fetch`/`pull`/`push` run **inside** the Claude Code sandbox prompt-free (`github.com` is in the sandbox network allowlist; SSH/port-22 is not). Raw SSH still works but needs the sandbox disabled — fallback only.
3. **Network**: always `curl --max-time 10`.
4. **Branch = Environment**: `main` = Production. Else = Preview/Dev.
5. **CLI non-interactive**: always `-y` (Vercel, Modal). `printf` not `echo` for env values.
6. **File-Sync**: copying source → destination: Read BOTH first.
7. **Backend services don't auto-deploy**: Convex + Modal are manual; deploy backend BEFORE frontend test.
8. **Stack-verification before recommending**: run the `stack-detection` skill before flagging missing components in a project.
9. **Git freshness before reasoning**: `git fetch` and verify it succeeded before drawing any conclusion from git state. Failed/blocked fetch → fail loud, label findings as possibly stale. (A `fatal: failed to store` line with exit 0 is harmless keychain noise, not a fetch failure.) Details: `~/.claude/rules/git-freshness.md`.
10. **Deploy scripts follow the 10-gate checklist**: never create or modify a deploy script without `~/.claude/rules/deploy-safety.md` (its path-trigger is unreliable — read it explicitly).
11. **Git worktree removal is never sandboxed**: `git worktree remove` deletes all working files before it hits the denied `.git` paths, leaving a half-destroyed worktree whose own safety check is then useless. Run it unsandboxed on the first attempt and verify content is on `main` first: `~/.claude/rules/git-worktree-sandbox.md`.
12. **Deleting from a shared location breaks whoever links to it.** `~/.agents/skills/` is symlinked into every harness. Before removing anything there, check for inbound links (`find ~ -maxdepth 5 -type l -lname '*<name>*'`) and clean them in the same pass, or you trade one dead entry for several dangling ones.
13. **A guard that cannot fire looks exactly like a guard that found nothing.** Any hook, check, or gate that exists to catch a specific condition needs a reproduction of that condition — including on the riskiest branch. Wrong output schema and always-empty diffs both report green. See `~/.claude/runbooks/deploy-safety-postmortem.md`.
