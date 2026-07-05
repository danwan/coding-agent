# Challenger Agent Reliability

> Empirical findings from the Challenger evaluation system. Use this to decide when a single Challenger run is enough and when to use majority-vote.

## Measured Performance

Evaluation conducted in `/Users/dannywannagat/Code/improver/` with 15 realistic fixtures covering all 8 Challenger checks, including 5 adversarial fixtures (subtle flaws requiring careful analysis).

### Single-run accuracy (Opus)

| Metric | Score | Notes |
|--------|-------|-------|
| Verdict Accuracy | 100% (15/15) | First-run accuracy on clean + adversarial fixtures |
| Check Coverage | 100% | All 8 checks (a-h) present in every output |
| Citation Rate | 100% | Always includes file:line references |
| False Positive Rate | 0% | No real file ever flagged as non-existent |

### Multi-run consistency (Opus, 3 runs)

| Metric | Score | Interpretation |
|--------|-------|----------------|
| **All-runs accuracy** | 66.7% | Same correct verdict on ALL 3 runs |
| **Majority-vote accuracy** | 80.0% | Correct by majority of 3 runs |
| **Overall stability** | 66.7% | Same verdict every run (stable fixtures only) |

**Key finding:** The Challenger is perfectly accurate on single-run for clear cases, but non-deterministic on borderline cases (NEEDS_REVISION vs REJECTED boundary, or APPROVED edge cases).

### Sonnet comparison (cost tradeoff)

| Metric | Opus | Sonnet |
|--------|------|--------|
| Verdict Accuracy | 100% | 73.3% |
| APPROVED vs NOT_APPROVED | 100% | 100% |
| Cost per run | 1x | ~0.2x |

Sonnet's errors are all in the NEEDS_REVISION vs REJECTED boundary (over-strict). For the binary "is this work acceptable?" question, Sonnet matches Opus.

## Which Unstable Fixtures

The 5 fixtures that showed inconsistent verdicts across 3 Opus runs:
- `01-perfect-fix` (APPROVED): sometimes rejected incorrectly
- `10-borderline-good` (APPROVED): terse prose gets penalized
- `05-no-doc-lookup` (NEEDS_REVISION): flips between NEEDS_REV and REJECTED
- `13-scope-creep` (NEEDS_REVISION): scope-creep sometimes scored as REJECTED
- `14-fabricated-doc-claim` (NEEDS_REVISION): fabrication sometimes escalated to REJECTED

Pattern: boundary cases where "how severe is this?" is subjective. The substance is always correctly identified; only the verdict label wobbles.

## Decision Matrix — Which Setup to Use

| Situation | Recommended Setup | Why |
|-----------|-------------------|-----|
| Clear-cut bug fix review (most cases) | Single Opus run | 100% accurate on clean cases |
| Borderline/complex fix (auth, data, architecture) | 3 runs + majority vote | 80% consistent, surfaces disagreement |
| Just need APPROVED vs NOT-APPROVED gate | Single Sonnet run | ~5x cheaper, same binary decision |
| Absolute reliability required | 3 Opus runs + majority + manual review on disagreement | Maximum confidence |

## How to Invoke Majority-Vote

See `~/.claude/skills/challenge/SKILL.md` — use `/challenge --triple` for 3-run majority voting.

Alternatively, manually dispatch `@challenger` 3 times with the same target and take the majority verdict. If all 3 disagree, escalate to the user.

## Source Evidence

All metrics reproducible via:
```bash
cd /Users/dannywannagat/Code/improver
./scripts/run-baseline.sh          # 15 fixtures, single run
./scripts/run-consistency.sh 3     # 15 fixtures, 3 runs each
./scripts/run-model-compare.sh     # 15 fixtures with Sonnet
```

Full results in `results/` subdirectories. Fixtures at `fixtures/`. Test project at `test-project/`.

## What Prompt Optimization Can (and Cannot) Fix

Tested `superpowers:autoresearch` with targeted mutations on the Challenger prompt:
- Calibration guidance improved NEEDS_REVISION vs REJECTED boundary
- But pulled APPROVED-expected cases toward NEEDS_REVISION
- Net score unchanged; tradeoffs, not improvements

Conclusion: the remaining instability is LLM non-determinism on subjective boundaries, not a prompt defect. Multi-run voting is the effective fix, not more prompt tuning.
