# Coding Discipline

Three pre-action tripwires — each is one sentence the agent must answer before Write/Edit.

## A. Scope Discipline

Match what you change to what was asked. Don't bundle cleanup into a bug fix. Don't refactor during a rename. Don't add helpers during a one-shot fix.

**Allowed adjacent edits** (no ask): import follow-through after renames, dead code adjacent to deleted callsites, type signature ripples from deliberate signature changes.

**NOT allowed without asking**: "while I'm here" cleanup, drive-by formatting outside touched lines, unrequested tests/docs/refactors, renames outside scope.

**Pre-action check:** *"Is this Write/Edit inside the requested scope, or am I expanding it? If expanding — ask first."*

## B. Simplicity First (Proactive)

`simplify` and `pr-review-toolkit:code-simplifier` cover this reactively. This rule moves it to planning time.

**Name what was cut.** A plan with no cut features, no rejected abstractions, no "we don't need X yet" is suspect.

**Justify abstractions in one line.** Three similar lines beats premature abstraction. For feature scope: defer to `avoid-feature-creep`.

**Pre-action check:** *"What did I cut from this plan, and why is the abstraction (if any) load-bearing today, not someday?"*

## C. Success Criteria Upfront (new features)

Bug fixes have TDD as the gate; new features lack the equivalent. "Build feature X" drifts without a clear shape of done.

**Write one observable success criterion before coding.** Observable = a specific command that succeeds, a specific UI behavior verified in a browser, or a specific E2E/integration test that passes (unit tests rarely prove a feature works).

Vague "user can sign up" → concrete "POST /api/signup returns 201 with session cookie; cookie authenticates GET /api/me." That sentence is the contract for `superpowers:verification-before-completion`.

**Pre-action check:** *"What's the one observable thing that proves this feature works? If I can't name it, I'm not ready to write code."*
