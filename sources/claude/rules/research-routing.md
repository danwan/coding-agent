# Research Routing (Docs & Web Tools)

> Which tool answers an external-knowledge question. Local search (rg/fd/qmd) lives in `search-discipline.md` — this file is only docs + the open web.

## Decision order

**Skill → Context7 → Exa → built-in web.** Stop at the first that fits.

1. **A skill covers it?** Use the skill (beats everything below).
2. **Is the question "what do the docs say"** about a named library / framework / SDK / API / CLI / cloud service? → **Context7**.
3. **Is it "what does the web say"** — current events, comparisons, pricing, "latest", blog posts, GitHub issues, anything not in official docs? → **Exa**.
4. **Just need one known URL fetched, summary is fine?** → built-in **WebFetch**.

## Tool table

| Need | Tool |
|---|---|
| Topic has a matching skill | **Skill first** |
| Library/API docs, syntax, config, version migration, CLI usage | **Context7** (`mcp__claude_ai_Context7__*`) |
| Library-specific debugging | **Context7** |
| Semantic / "find me sources about X" research | **Exa** `web_search_exa` |
| Full text/content of a web page | **Exa** `web_fetch_exa` |
| Summary of one named URL (lossy, cheap) | built-in `WebFetch` |
| Quick keyword web lookup | built-in `WebSearch` or `web_search_exa` |
| Deep multi-source, fact-checked report | **`deep-research` skill** (orchestrates Exa fan-out) |

Use Context7 even when you think you know the answer — training data drifts.

## Do NOT route to Context7 or web

General programming concepts, refactoring, writing scripts from scratch, business-logic debugging, code review — these are reasoning tasks, not lookups. Context7's own instructions exclude them.

## Pre-action check

*"Is this a skill, a docs lookup (Context7), or open-web (Exa)? Am I about to web-search a library when Context7 would answer?"*
