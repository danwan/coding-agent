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

## Pre-action check

*"Project docs checked first, cheapest tool for the domain — or am I reading a whole file when a `rg` line would do?"*
