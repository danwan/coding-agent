---
name: code-search
description: Use when searching source code — selecting between rg, fd, ast-grep, jq, and tree, and choosing Explore-subagent vs direct Bash. Triggers on multi-step code search, structural pattern matching, or JSON config inspection. NOT for markdown docs/notes (use qmd CLI or mcp__qmd__* tools instead) or past sessions (use memsearch:memory-recall skill instead).
---

# Code Search

Cookbook for source-code search. The always-loaded rule `~/.claude/rules/search-discipline.md` covers the high-level routing; this skill provides the concrete commands.

## Out of scope (route elsewhere)

- **Markdown docs / notes / knowledge base** → use `qmd` CLI via Bash (e.g. `qmd query "rate limiter"`) or the `mcp__qmd__*` MCP tools (semantic + lex/vec/hyde search)
- **Past Claude sessions / historical decisions** → invoke the `memsearch:memory-recall` skill

This skill covers source code only.

## Tool selection

### `rg` — text, symbols, routes, env vars

Default for almost any string-based search.

```bash
rg "loginUser" src
rg "DATABASE_URL" .
rg "/api/auth" src
rg -t ts "useEffect"            # restrict by language
rg -l "TODO"                    # files only
rg -n -C2 "panic\\!" src         # with context
```

Flags worth knowing: `-l` (files only), `-n` (line numbers, default), `-C N` (N lines context), `-t LANG` (file type), `--hidden` (search dotfiles), `-g '!**/foo/**'` (glob exclude).

### `fd` — file discovery

Use when you need files, not content.

```bash
fd "auth" src
fd "schema" .
fd -e ts -e tsx src             # by extension
fd -H ".env"                    # include hidden
fd -t f -d 2                    # files only, depth 2
```

### `ast-grep` / `sg` — structural patterns

Use when regex would give too many false positives or the structure matters.

```bash
ast-grep --lang ts -p 'console.log($$$)' src
ast-grep --lang tsx -p 'useEffect($CALLBACK, [])' src
ast-grep --lang ts -p 'await $FUNC($$$)' src
ast-grep --lang ts -p 'try { $$$ } catch { $$$ }' src    # silent catches
```

`$VAR` matches a single node; `$$$` matches multiple. The binary alias `sg` works the same.

**When `ast-grep` beats `rg`:**
- Finding all calls to a function regardless of formatting/whitespace
- Finding empty/silent catch blocks
- Finding hooks with specific dependency-array shapes
- Refactoring patterns where line-by-line regex misses multi-line forms

When `rg` is enough: simple identifier search, exact strings, error messages.

### `jq` — JSON

```bash
jq '.scripts' package.json
jq '.dependencies | keys' package.json
jq -r '.compilerOptions.paths' tsconfig.json
jq '.[] | select(.active == true)' data.json
```

### `tree -L 2` — quick project map

```bash
tree -L 2 -I 'node_modules|.next|dist|build|.venv'
```

Use sparingly — for first-look orientation only, not as a routine step.

## Direct Bash vs Explore subagent

| Situation | Choice |
|---|---|
| 1–2 targeted queries, known area of code | Direct `Bash` (rg/fd/ast-grep) |
| Unknown repo, need to map structure | Explore subagent |
| 3+ exploratory queries chained | Explore subagent |
| Open-ended "where is X handled" with no leads | Explore subagent |
| Result will be large and you only need a summary | Explore subagent (keeps main context clean) |

Threshold heuristic: **≥3 queries OR result >200 lines OR unfamiliar repo → Explore.** Otherwise direct.

## Workflow when starting a task

1. If `docs/codebase-overview.md` exists → read it first.
2. Form a hypothesis about which file/folder to look in.
3. `fd` to confirm files exist, then `rg` for the symbol/text.
4. Only `Read` the matching file (with `offset`/`limit` if large).
5. If 3+ queries didn't pin it down → switch to Explore subagent instead of grinding.

## Avoid

`node_modules/`, `.next/`, `dist/`, `build/`, `coverage/`, `.venv/`, `__pycache__/`, `target/`, generated files, large logs. Most tools (`rg`, `fd`) skip `.gitignore`'d paths by default — don't add `--no-ignore` without reason.
