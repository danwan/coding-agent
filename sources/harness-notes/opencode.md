# OpenCode — translation notes

You are translating the canonical `sources/claude/` content into OpenCode's
format. Check your **own current docs / config schema** for exact fields — the
below is the durable mapping.

## Where things go
- **Global instructions + rules:** OpenCode loads instruction files by glob.
  Point its `instructions` list at your placed `AGENTS.md` **and** at the rule
  files from `sources/claude/rules/` directly — no need to copy their text into
  one file, and no per-tool rule dir needed. All rules load as-is.
- **Subagents:** `sources/claude/agents/*.md` → OpenCode agent `.md` files.
  Keep the body verbatim; map the frontmatter (below).
- **Skills:** OpenCode reads `~/.agents/skills/*/SKILL.md` directly — the shared
  hub is enough; no per-tool skills dir.
- **Commands:** marketplace slash-commands (e.g. `/commit`, `/commit-push-pr`,
  `/clean_gone`) have no marketplace here — reproduce them as native command
  files. There is no inline command-eval syntax, so spell out "run these first".

## Frontmatter mapping (map to current keys)
| Claude | OpenCode |
| --- | --- |
| `tools: Bash, Read` | `permission: { bash: allow, read: allow }` |
| `model: <tier>` | your provider model id for that tier — resolve it yourself |
| `maxTurns: N` | `steps: N` |
| subagent scope | `mode` |

## No schema equivalent — document and skip (don't fake it)
`sandbox.*` (network/filesystem isolation), `statusLine`, `env` block, TUI prefs
(theme/vim/fullscreen), auto-memory/dream, and Claude-marketplace-only plugins.
MCP servers that are claude.ai-account-bound (Exa, Gmail, Calendar, Drive, …)
have no portable standalone form. Configure MCP `context7` (remote URL + API-key
header) and any OAuth remote MCP; skip the rest. Rationale + the full mapping:
`docs/harness-research/opencode-translation-reference.md`.
