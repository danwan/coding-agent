---
name: grill-me
description: Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. Use when the user wants to stress-test a plan, get grilled on their design, asks you to "grill me", "challenge my plan", "poke holes", "interview me", or proposes a plan that has obvious gaps or unstated assumptions — even when they don't explicitly invoke the skill.
---

# Grill Me

A structured interview to stress-test a plan or design. The aim is shared understanding — every load-bearing decision examined, every unstated assumption surfaced — so subsequent execution doesn't drift on hidden disagreements.

This skill is for **after** the user has a rough plan in mind. It's not brainstorming (use `superpowers:brainstorming` for vague → concrete), and it's not formalization (use `superpowers:writing-plans` once the plan is settled). It sits between the two.

## When to use

Trigger when:
- The user explicitly asks: "grill me", "challenge my plan", "poke holes in this", "interview me on X", "stress-test this"
- The user proposes a plan with obvious unstated assumptions, undefined boundaries, or unresolved trade-offs
- The user asks for a sanity-check on a design before coding starts

Don't trigger when:
- The task is a concrete bug fix or one-shot edit (no decision tree to traverse)
- The user clearly wants validation, not pressure — read the cue

## The core loop

1. **Map the decision tree** — before asking anything, sketch the branches. State them back so the user can correct your reading and reorder.
2. **Pick the most blocking branch** — the one whose answer constrains others. Resolve roots before leaves.
3. **Ask one question, with your recommended answer** — see "How to ask" below.
4. **Drill down or move sideways** — based on the answer, either follow the branch deeper or close it and move to the next blocking one.
5. **Stop when the tree is resolved or the user calls it** — then synthesize.

The discipline of one-question-at-a-time matters because it lets the user push back on each decision in isolation. Batching three questions invites three batched, shallow answers.

## Mapping the decision tree

Before the first question, output a compact tree of what you see as the open decisions:

    Plan: [one-line summary of what you understood]
    Open branches:
      1. [decision] — depends on: none
      2. [decision] — depends on: 1
      3. [decision] — depends on: 1
      4. [decision] — depends on: 2, 3

This serves two purposes: (a) the user can correct your reading before you waste questions, and (b) it gives you a working agenda.

The tree will grow. As answers reveal new branches, add them and surface the addition: "That opens a new question about X — adding it to the tree."

## How to ask

**Always commit to a recommended answer.** Never ask open-ended "what do you think?". Phrase as: "I'd suggest X because Y. Push back if Z." This forces you to actually reason about the decision before bouncing it back, and gives the user something concrete to react to instead of having to generate from scratch. A recommended answer is also a small bet — if you're wrong, the user's correction teaches you something the question alone wouldn't have.

**Prefer the `AskUserQuestion` tool for discrete choices.** When the answer space is finite (auth method, library choice, scope yes/no, naming), use it. Put your recommended option first with `(Recommended)` appended to the label. This is faster for the user than typing prose, and the structure surfaces alternatives you actually considered.

**Use free-form prose questions when the answer space is genuinely open** — values, names, free-form constraints, anything where listing 2-4 options would be artificial. Still lead with your recommended answer; just ask it as a sentence.

**One question per turn.** Even if `AskUserQuestion` allows up to 4 questions in a batch — don't. The point is depth per branch, not breadth per turn. The only exception: two questions that are genuinely independent *and* both blocking can share a turn — but that's rare, and when in doubt, split.

## Codebase first

If a question can be answered by reading the code, read the code. Don't ask the user "how does auth currently work?" if you can `grep` or `Read` for the answer. Asking what's already knowable wastes the user's attention and signals you haven't done the work.

This applies to: existing patterns, current dependencies, file layout, naming conventions, schema shape, env var names, function signatures, what tests cover today.

It does **not** apply to: design intent, priorities, trade-off preferences, future scope, why-decisions, deadlines, stakeholder constraints — those are the user's calls and no amount of grepping will surface them.

When you do look something up, say so briefly: "Checked `src/auth/session.ts` — sessions are 256-bit hex, 30-day TTL. Moving on." This shows your work and lets the user correct stale code-reads.

## Stopping

Stop when:
- Every open branch in the tree has a resolved answer
- The user says "done", "enough", "that's it", "let's go", or otherwise signals the grilling should end
- You hit a branch the user isn't ready to resolve — log it as deferred and stop rather than spinning

Don't keep grilling out of completeness if the user is clearly satisfied. Diminishing returns are real, and the goal is shared understanding, not exhaustion.

## End-of-grill synthesis

Once stopped, produce a compact summary inline (no file — the user will use it directly or feed it into `superpowers:writing-plans`):

    ## Decisions
    - [decision 1]: [resolved answer]
    - [decision 2]: [resolved answer]
    ...

    ## Deferred / open
    - [question]: [why deferred or what's needed to resolve]

    ## Suggested next step
    [one sentence — e.g., "Write the plan with these decisions" or "Spike the X branch before deciding Y"]

Keep it tight. The synthesis is a reference, not a document.

## Anti-patterns

- **Asking without recommending.** "What auth method do you want?" → no. "I'd use session cookies with HttpOnly; SameSite=Strict over JWT because the app is server-rendered and there's no third-party consumer. Disagree?" → yes.
- **Batching questions.** "Also, what about rate limiting and logging?" — split each into its own turn.
- **Random tree-walking.** Don't ask about caching strategy before resolving whether there's a server at all. Dependencies first.
- **Asking the codebase what only it can answer.** If `Read`/`grep` would resolve it, do that instead.
- **Performative agreement.** If the user's answer creates a contradiction with an earlier branch, surface it: "That conflicts with the decision in branch 2 — which one moves?". Don't paper over.
- **Endless grilling on trivia.** Edge cases that won't change the design aren't worth a turn. Surface them as "minor — flag in the plan" and move on.
- **Theatrical adversariality.** The point isn't to be hostile; it's to think rigorously together. Recommended answers should be your honest best guess, not deliberately provocative.

## Language

Match the user's language. If they're writing in German, grill in German. If English, English. Mixed is fine if that's how they write.
