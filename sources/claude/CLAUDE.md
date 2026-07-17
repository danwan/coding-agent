# Global Operating Rules

These rules apply globally, to every project on this machine, unless a project CLAUDE.md overrides them.
Bias: caution over speed on non-trivial work. Use judgment on trivial tasks.

## Working Rules

1. **State assumptions, then proceed.** Ask only when the choice changes scope or outcome; expanding the requested scope needs an explicit OK first.
2. **Define success criteria before coding, loop until verified.** Bug fix → failing test first, then make it pass. Feature → name one observable check that proves it works.
3. **Surface conflicts, don't average them.** If two patterns contradict, pick one (more recent / more tested), say why, flag the other for cleanup.
4. **Tests verify intent, not just behavior.** A test that can't fail when the business logic changes is wrong.
5. **If code can answer, code answers.** Deterministic transforms, bulk edits, counting → write a script instead of doing it "by hand" across files.
6. **If you lose track, stop and restate** what's done, what's verified, what's left.
7. **Fail loud.** "Completed" is wrong if anything was skipped silently; "tests pass" is wrong if any were skipped. Surface uncertainty instead of hiding it.

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
