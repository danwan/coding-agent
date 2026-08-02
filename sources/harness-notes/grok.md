# Grok — translation notes

Grok is the one harness that needs **no translation and no copies**. Check your
own current docs for exact field names; the durable part is the principle below.

## Grok reads Claude's config directly — do not duplicate it

Grok ships harness-compatibility scanning that is **on by default**. It reads the
home-level Claude locations as first-class sources: the global instruction file,
`~/.claude/rules/*.md`, `~/.claude/skills/`, the permissions in
`~/.claude/settings.json`, the MCP servers in `~/.claude.json`, and the hooks in
`~/.claude/settings.json`.

That makes the canonical content available in Grok the moment Claude Code has it.
So:

- **Place nothing** under `~/.grok/rules/`. Grok scans its own home rules *and*
  Claude's, in that order, and concatenates both — a copy loads every rule
  **twice** into every session. `sync.sh` deliberately has no placement step for
  Grok and warns if `~/.grok/rules/` is non-empty.
- **Link no skills** into `~/.grok/skills/` that already exist in the shared hub
  via `~/.claude/skills/`. Duplicates show up twice in the skill list.
- Verify with `grok inspect`: the authored rules must appear with the Claude
  source tag, each exactly once.

Turn a compat source **off** rather than working around it, if a harness leaves
this setup's scope — otherwise Grok keeps loading that tool's leftovers. This
setup disables the Cursor compat cells for exactly that reason.

## The one Claude compat cell that is deliberately OFF

`[compat.claude] mcps = false` — set 2026-08-02.

Left on, Grok merges every MCP server from `~/.claude.json`, and that file holds
more than this repo's own legs: the claude.ai account connectors appear there too
(`claude.ai <name>`). Inheriting them means a second harness reaches those
third-party services with no separate approval step, and nothing in this repo
records or gates it — the account level is explicitly out of scope here.

**What this costs:** Grok starts with no MCP servers at all. Anything it genuinely
needs has to be declared in `~/.grok/config.toml` under its own per-server table.
That is the point — an explicit list beats silent inheritance — but it is real
work, and Grok loses Context7 until that leg is added there.

**To reverse:** delete the cell (the default is on). Do not "work around" it by
copying servers into Grok's config *and* leaving inheritance on; the servers then
load twice.

## What Grok does NOT inherit

- **Subagents.** The Claude compat cell for `agents` covers *instruction* files,
  not subagent definitions. `~/.claude/agents/*.md` is not read as agent types,
  so the four authored subagents are unavailable in Grok. Its own agents live in
  `~/.grok/agents/` (markdown + frontmatter) and would have to be written
  separately; `sync-agents.py` deliberately does not target Grok. Accept the gap
  or write them — do not half-copy them.
- **Skill enable/disable state.** Claude's per-skill overrides are not inherited;
  Grok sees every skill in the hub as active. Mirror the intended-off set in
  Grok's own skills config, or the deliberately disabled skills come back.

## Everything else

- **MCP servers:** configured in `~/.grok/config.toml` under a per-server table,
  with both stdio (command/args/env) and remote (url/headers) transports. The
  same secret rule applies as everywhere: reference an environment variable, never
  a literal key — and remember that anything inherited from `~/.claude.json`
  arrives with whatever form that file uses.
- **Hooks:** `~/.grok/hooks/`. Only the external Orca integration hooks belong
  here; this repo authors none.
- **Plugins:** its own marketplace, separate from Claude's. The same selection
  rule from `PROVISION.md` applies — a plugin must provide a capability the model
  does not have.
