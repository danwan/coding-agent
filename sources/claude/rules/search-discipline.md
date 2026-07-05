# Search & File-Reading Discipline

> Cheapest precise search first. Narrow before reading. Pick the right tool for the domain.

## 1. Read project docs first (if present)

Before any broad code search, check whichever of these exist:
- `docs/codebase-overview.md`
- `docs/features.md`
- `docs/decisions/`
- `docs/runbooks/`
- project `CLAUDE.md`

These are produced by the `project-docs` skill family and usually answer "where does X live" without reading code.

## 2. Pick the tool by domain

| Search target | Tool / Skill |
|---|---|
| Source text, symbol, route, env var, error message | `rg` (Bash) |
| File by name or extension | `fd` (Bash) |
| Structural code pattern (AST-aware) | `ast-grep` / `sg` (Bash) |
| JSON config inspection | `jq` (Bash) |
| Quick project map | `tree -L 2` (Bash) |
| Markdown docs, notes, runbooks, knowledge base | `qmd` CLI (Bash) or `mcp__qmd__*` MCP tools |
| Past Claude sessions, historical decisions | invoke `memsearch:memory-recall` skill |
| Code-tool deep examples (rg/fd/ast-grep/jq cookbook, ast-grep templates) | invoke `code-search` skill |

## 3. Read only what's needed

Use `Read` with `offset`/`limit` for files >500 lines or when only a section is needed. Don't read whole files when a `rg` hit gave you the line.

## 4. Avoid (skip unless explicitly required)

`node_modules/`, `.next/`, `dist/`, `build/`, `coverage/`, `.venv/`, `__pycache__/`, `target/`, generated files, large logs.

## 5. Built-in vs Bash vs Explore subagent

- Single targeted lookup → built-in `Grep`/`Glob`/`Read`
- 3+ exploratory queries or unfamiliar repo → `Agent` with `subagent_type=Explore` (keeps main context clean)
- CLI power tools (`rg`, `ast-grep`, `jq`, `qmd`) → via `Bash` or via their dedicated skill

## Pre-action check

*"Have I checked the project docs first, and am I using the cheapest tool for this domain — or am I about to read a whole file when a `rg` line would do?"*
