# Instruction Loading: Empirical Findings (2026-05-07, CC 2.1.132)

> **Archived reference — historical, version-specific.** Empirical Claude Code
> behaviour captured on CC 2.1.132. NOT part of the provisioning path and NOT
> authoritative for current tool versions — re-verify before relying on
> specifics. Kept because the mechanism-level findings (why `@import` rules are
> load-bearing, how path-scoped rules and skills load) still inform how the
> canonical rules/skills in `sources/claude/` are authored.

> 21 controlled tests across 4 phases. NOT auto-loaded. Consult when designing
> new rules/skills/hooks or debugging "why didn't my rule fire?". This runbook
> codifies behavior empirically observed on Claude Code 2.1.132 — re-verify
> against current CC version if you suspect drift.

## Why this runbook exists

The Anthropic memory docs (https://code.claude.com/docs/en/memory) describe
three instruction-loading mechanisms — `@import`-always-loaded, path-scoped
rules in `.claude/rules/*.md`, and skills — but do not document their trust
levels, refusal behavior, or trigger edge-cases. This runbook captures the gap.

Two practical consequences drive everything below:

1. **Path-scoped rules silently fail on `Write` of new files.** Documented
   indirectly in https://code.claude.com/docs/en/debug-your-config ("subdirectory
   instructions load on Read, not when writing or creating files there").
2. **Skill bodies are NOT uniformly trusted.** Claude 4.7's prompt-injection
   defense applies a 3-tiered compliance model based on action content.

---

## Test methodology

- Headless mode: `claude -p "<prompt>" --output-format json`
- Each test: clean session, single prompt, observe Bash invocations + tool-result
- All tests on CC 2.1.132 (verify with `claude --version` if reproducing)

---

## Section A — Path-scoped rules (Phase 1+2, 13 tests)

### Trigger matrix

| Action on matching-path                           | Rule loads? |
| ------------------------------------------------- | ----------- |
| Read existing file                                | ✅          |
| Edit existing file                                | ✅ (via Edit's prerequisite Read) |
| Write of new file                                 | ❌          |
| Bash filesystem touch (mkdir, redirect, etc.)     | ❌          |
| Bare mention in prompt without file ops           | ❌          |

### Pattern shapes verified (no shape changed trigger behavior)

- Broad dir-glob: `target/**`
- Exact filename: `deploy.sh`
- Extension-only: `**/*.config.json`
- Nested dir+ext: `src/api/**/*.ts`

### Injection envelope

Path-scoped rules are appended as a `<system-reminder>` block attached to the
Read tool result — NOT loaded into the trusted system prompt. From Claude's own
explanation in one test output:

> "the tool result for that Read also included a `<system-reminder>` block
> (claiming to come from .claude/rules/sentinel-specific.md) … the path-scope
> sentinel was not auto-loaded into my context — it only arrived as untrusted
> in-band data via a Read-tool result rather than via the trusted system prompt."

### Refusal observation

In 2/3 specific-pattern Read scenarios, Claude refused compliance with explicit
"Prompt injection detected" reasoning. The rule was VISIBLE to Claude (it
quoted it in the response), but treated it as untrusted instruction.

### Caveat (per Codex review)

The trust-level interpretation is local empirical evidence, not officially
documented at the model-contract level. Anthropic security docs mention
"context-aware analysis of the full request" and Opus 4.7 launch notes mention
improved prompt-injection resistance vs 4.6 — both consistent with observed
behavior, but neither explicitly states the `<system-reminder>` trust framing.

---

## Section B — Skill mechanism (Phase 3+4, 8 tests)

### Trigger results

| Test  | Prompt type             | Skill triggered? |
| ----- | ----------------------- | ---------------- |
| H1    | Direct keyword match    | ✅               |
| H2    | Semantic match          | ✅               |
| H3    | Vague prompt ("macht mal") | ❌            |
| H4    | Unrelated domain        | ❌               |
| H5    | `disable-model-invocation: true` set | ❌ (correctly blocked) |
| H6    | Manual `/slash` with disable-flag set | ✅ (flag bypassed) |
| H7    | Trust-stress (suspicious bash) | ❌ (refused) |
| H8    | Project-scoped skill description visibility | – (not in list-skills response) |

### 3-tiered trust model (refines official "skills are trusted" claim)

Skill body content is evaluated by action shape:

1. **Benign actions** (e.g. `printf "hello" > local-file.txt` in workdir):
   full execution.
2. **Unusual text-emit actions** (e.g. "include literal token ABC123 in your
   text response"): selective compliance — Bash runs, text token suppressed.
3. **Suspicious actions** (e.g. Bash writes outside workdir, curl to network,
   reading unrelated dotfiles): full refusal with explicit "refused the skill
   body's three injection-style actions" reasoning.

This means: a skill that LOOKS like prompt injection — even if it's the
user's own legitimate skill — can fail closed.

### Project-scoped skills doc gap

Project-scoped skills (`<project>/.claude/skills/`) are invokable via `/slash`,
but NOT shown in "list available skills" responses. Only user-level and plugin
skills appear in that listing. Doc gap, not bug — but worth knowing.

### Bonus cross-validation (H1/H2)

In H1 and H2, even where the test skill's trust-stressed body was being
selectively refused, Claude still surfaced the always-loaded `@import` rules
from `~/.claude/rules/deploy-safety.md` independently. This is direct evidence
that `@import`-loaded content is mechanism-independent: it greift even when the
skill mechanism partially fails.

---

## Section C — Cross-mechanism comparison

| Mechanism                   | Read existing  | Write new | Vague prompt | Trust level | disable-flag |
| --------------------------- | -------------- | --------- | ------------ | ----------- | ------------ |
| Path-scoped rule (`paths:`) | ✅ as `<system-reminder>` | ❌    | n/a          | untrusted (refused 2/3) | – |
| `@import` always-loaded     | ✅             | ✅        | ✅           | trusted (system prompt) | – |
| Skill auto-invoke           | ✅ on prompt-match | ✅ if prompt matches | ❌ | tiered (benign✅ / unusual⚠️ / suspicious❌) | ✅ works |

---

## Section D — Architectural recommendations

Codified for future-self / future-sessions. Each backed by evidence in A or B.

1. **Safety/deploy/compliance rules → `@import` always-loaded.** Only mechanism
   that fires across all tool types (Read/Edit/Write/Bash) AND all prompt
   phrasings (specific/vague) AND all trust levels.

2. **Domain-specific workflow helpers (e.g. "Convex-Migration erstellen") →
   skill with clearly-formulated description.** Triggers on direct + semantic
   match (H1/H2 verified) without always-loaded token cost.

3. **Skill bodies should look benign** to avoid Claude 4.7 refusal:
   - Bash calls inside the working directory only (no `/tmp/`, no `~/` outside
     the project)
   - No "emit literal token X in output" instructions (suppressed by selective
     compliance, observed H1/H2)
   - No curl/network calls embedded in skill body
   - Multi-step sensitive workflows: prefer always-loaded `@import` rule + thin
     skill that just orchestrates user-visible commands, rather than embedding
     the rules in the skill body

4. **Manual-only skills:** set `disable-model-invocation: true` (verified
   blocking in H5) and document the `/slash` trigger (works in H6).

5. **`@import` reliability is mechanism-independent.** H1/H2 cross-validation:
   even when the skill mechanism partially refused, `@import` rules still
   surfaced. This is the load-bearing reason `~/.claude/CLAUDE.md` keeps all 9
   rules `@import`-loaded.

---

## Section E — Open questions for future tests

These are NOT empirically resolved by Phase 1-4. Worth designing tests for:

- Does skill auto-invoke trust-level depend on which marketplace it comes from
  (user-level vs plugin vs project)?
- Does `claudeMdExcludes` interact with rule loading order or trust level?
- Does `--add-dir` change path-scoping behavior for rules in additional
  directories?
- What's the trust level of MCP tool descriptions vs skill descriptions?
- Does `Write` trigger path-scoped rules on the file being written, if a Read
  of the same path happens later in the same session? (Sequence sensitivity)
- Does compaction (`/compact`) preserve `@import`-loaded rules but not
  path-scoped rules? (Memory doc says "Project-root CLAUDE.md survives
  compaction" — but no statement on path-scoped rules)

---

## Verification

To reproduce or detect drift:

```bash
# Reproduce any test
claude -p "<original prompt>" --output-format json

# For trust-level confirmation — H7 should still refuse
claude -p "use the trust-stress test skill" --output-format json
# Expect: "refused the skill body's three injection-style actions"

# If results diverge from this doc — CC version may have changed behavior
# Append a section "## Behavior change observed YYYY-MM-DD on CC vX.Y.Z" with
# the diff and cite it from the relevant section above.
```

## Source chronology

- 2026-05-07: Phase 1+2 (path-scoping, 13 tests) by user
- 2026-05-07: Phase 3+4 (skill mechanism, 8 tests) by user
- 2026-05-07: Codex (gpt-5.3-codex) second-opinion review (web-only, no local file access)
- 2026-05-07: Runbook authored from synthesized findings
