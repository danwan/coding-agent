---
name: challenge
description: Dispatch the @challenger agent to stress-test a sub-agent's output (bug fix, root-cause analysis, or debug conclusion) against first-answer bias and the TDD-bug-fix gate.
disable-model-invocation: true
---

# challenge

Dispatches the `@challenger` agent to critically review the most recent sub-agent output, or a specific target the user provides as an argument.

This skill is **explicit-only** (`disable-model-invocation: true`) — it never auto-triggers. Invoke when the user types `/challenge`, asks to "challenge" a result, or when the CLAUDE.md §9 Sub-Agent Dispatch Discipline requires a Challenger pass after a bug-fix or debug sub-agent.

## Usage

- `challenge` — challenge the most recent sub-agent output in this session (single Opus run).
- `challenge <target>` — challenge a specific target (file path, commit hash, PR number, or short description of the claim to verify).
- `challenge --triple <target>` — run the Challenger **3 times** and use the majority verdict. Use for borderline cases (auth, data access, architectural decisions).

## What the Challenger checks

The `@challenger` agent (see `~/.claude/agents/challenger.md`) runs eight mandatory checks:

(a) Root cause verified vs. guessed
(b) Context7 / official documentation consulted for external libs
(c) Every referenced file/function actually exists (Grep verification)
(d) Fix addresses cause, not just symptom
(e) Alternative explanations were considered
(f) **Hard gate for bug fixes:** failing test written FIRST, per `superpowers:test-driven-development`
(g) Test actually fails without fix and passes with it
(h) Verification claims backed by evidence (per `superpowers:verification-before-completion`)

## Output

`VERDICT: APPROVED | NEEDS_REVISION | REJECTED` plus per-check pass/fail with `file:line` citations and required actions.

## When to use

- After any bug-fix or debugging sub-agent finishes (mandatory per CLAUDE.md §9 Sub-Agent Dispatch Discipline).
- When you suspect a sub-agent took the first plausible hit without verification.
- Before accepting a fix that lacks a failing-test reference.

## Reliability

The Challenger is **100% accurate on clear-cut cases** but has **~67% consistency on borderline cases** across re-runs (LLM non-determinism on subjective boundaries).

- **Clear-cut case** → single run is reliable.
- **Borderline case** (NEEDS_REVISION vs REJECTED ambiguity, or APPROVED edge cases) → use `challenge --triple` to get majority-of-3 verdict (boosts accuracy from 66.7% to 80%).

## Action

### Single-run mode (default)
Dispatch `@challenger` once with the target context and report its full verdict back to the user. If `VERDICT ≠ APPROVED`, explain the required actions and offer to loop (max 2 retries) or escalate.

### Triple-run mode (`--triple`)
1. Dispatch `@challenger` 3 times with the same target and context (sequentially or in parallel).
2. Collect the 3 verdicts.
3. Report the **majority verdict** to the user.
4. If all 3 verdicts agree → report as "consistent verdict".
5. If 2 of 3 agree → report the majority verdict with a note that one run disagreed (include that run's key findings).
6. If all 3 disagree (rare) → escalate to user with all 3 verdicts side-by-side.
7. If majority is `NEEDS_REVISION` or `REJECTED`, proceed with recovery protocol using the majority's required actions.
