# Search & File-Reading Discipline

> Cheapest precise search first. Narrow before reading. Pick the right tool for the domain.

## 1. Read project docs first (if present)

Before any broad code search, check whichever of these exist:
- `docs/codebase-overview.md`
- `docs/features.md`
- `docs/decisions/`
- `docs/runbooks/`
- project `CLAUDE.md`

Where a project keeps them, they usually answer "where does X live" without reading code. Nothing generates them automatically — when you add one, the ADR and feature-spec templates are in `~/.agents/templates/`.

## 2. Pick the tool by domain

| Search target | Tool / Skill |
|---|---|
| Source text, symbol, route, env var, error message | `rg` (Bash) |
| File by name or extension | `fd` (Bash) |
| Structural code pattern (AST-aware) | `ast-grep` / `sg` (Bash) |
| JSON config inspection | `jq` (Bash) |
| Quick project map | `tree -L 2` (Bash) |
| Markdown docs, notes, runbooks, knowledge base | `qmd` CLI (Bash) or `mcp__qmd__*` MCP tools |

## 3. Direct Bash vs Explore subagent

**≥3 chained queries OR result >200 lines OR unfamiliar repo → Explore subagent.** Otherwise direct `Bash`. Explore keeps the main context clean when you only need the conclusion, not the file dumps.

## Pre-action check

*"Project docs checked first, cheapest tool for the domain?"*
