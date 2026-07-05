# Intent-Based Provisioning — Design Spec

- **Date:** 2026-07-04
- **Status:** Approved design, pre-implementation
- **Repo:** `coding-agent-setup` (private, source of truth) + `coding-agent-baseline` (public mirror)

## Problem

The current setup provisions machines with **scripts that encode the *how***:
`apply.sh` symlinks specific paths and translates authored files into five tool
formats; `capture.sh` scrapes the live `~/.claude` / `~/.config/opencode` dirs
back into `manifest/*.json`. Both are correct today and both **rot**: coding
agents and their config formats change every few months (skill dirs move,
`/plugin` semantics change, settings/hook schemas evolve). A script that hard-codes
today's paths and commands silently breaks against tomorrow's tool version, and
every agent update becomes repo-maintenance work.

Secondary pains this addresses:
- Reverse-capture is backwards: "install live, then scrape into the repo" produced
  a manifest with 34 global skills, including stack skills that should be project-local.
- The symlink model needs a clone at a stable path; it doesn't serve ephemeral/remote machines.

## Decision

Adopt an **intent-based model (A1)**: the repo documents **what** to install,
**from where**, and **why** — plus a one-line **verify** per item — and a **master
prompt** hands the *how/where* to the coding agent at run time. The agent knows
its own current layout better than any script we could freeze.

- **Tool scope: Claude-first.** The prompt provisions the Claude Code it runs in.
  Other agents (Codex/OpenCode/Cursor/Antigravity) self-provision by running the
  same prompt inside them; no central cross-tool translation.
- **Public baseline is rebuilt onto the same model** (not left on the old installer).
- **Explicit trade-off:** we trade determinism for durability. A frozen script is
  reproducible but rots; intent + agent-installs survives tool churn but each run is
  a judgment call. Mitigated by mandatory per-item `verify` (below).

This is a deliberate inversion of "code beats the model for deterministic transforms"
— that rule holds only while the code doesn't rot. Here the target (paths, commands,
schemas) is a moving target, so the durable encoding is intent, executed by the agent.

## Architecture

### Repo layout (private)
```
coding-agent-setup/
  SETUP-PROMPT.md        # THE master prompt (paste, or "read <URL> and run it")
  PROVISION.md           # intent: what / from where / why / verify — hand-curated
  sources/claude/        # authored, canonical: CLAUDE.md, rules/, runbooks/, hooks/, agents/
  sources/skills/        # own skills
  docs/…                 # this spec etc.
  scripts/publish-baseline.sh   # repo-maintenance only (generates the public mirror)
```
**Deleted:** `scripts/apply.sh`, `scripts/capture.sh`, `manifest/*.json`,
`OWNER-SETUP.md`, `baseline/install.sh` (the file-fetch installer).
**Note on "no scripts":** the principle targets *machine-provisioning* scripts that
encode tool-specific HOW and rot. Repo-maintenance scripts that only copy files
between the private and public repos (`publish-baseline.sh`) don't rot and stay.

### `PROVISION.md` format
Human- and agent-readable intent. Per entry: **what · from where · why · verify**.
No install commands (the agent picks the current one). Grouped by category, with
optional module groups (baseline / google / webservice). Example:
```markdown
## Plugins (Claude Code)
- superpowers — marketplace anthropics/claude-plugins-official
  why: full-lifecycle process skills (brainstorm/TDD/debug/verify)
  verify: appears in the /plugin list

## Remote skills (global)
- convex-* (11) — waynesutton/convexskills
  why: Convex work
  verify: `npx skills list -g` shows them

## MCP servers
- context7 — https://mcp.context7.com/mcp
  why: current library docs
  secret: CONTEXT7_API_KEY (op://Personal/context7/api-key)   # name + ref only, never a value
  verify: server lists tools

## CLI tools
- ripgrep — why: fast source search — verify: `rg --version`
```

### Master prompt (`SETUP-PROMPT.md`) behavior
1. **Detect.** Am I Claude Code? Owner (does `gh` reach the private repo)?
2. **Read intent.** `PROVISION.md` from a local clone if present, else online via `gh api`.
3. **Place authored files.** Fetch `sources/claude/*` + `sources/skills/*`; write them
   where *this* Claude version reads them; wire hook scripts into the *current*
   `settings.json` hook schema.
4. **Install intent items** using the mechanisms current at run time (the agent knows
   how `/plugin`, `npx skills add`, MCP config and the OS package manager work today).
5. **Verify.** Run every `verify` line; report PASS/FAIL. This replaces `apply.sh --check`.
6. **Prune (declarative, self-healing).** Diff what's installed/present against
   `PROVISION.md` + the authored set. Anything extra → ask per item: **remove**, or
   **adopt into `PROVISION.md`**. No hidden state file — the diff is recomputed each run,
   so `PROVISION.md` is the single source of truth.
7. **Ask only** the module menu (baseline / google / webservice).

Secrets: `PROVISION.md` names them + gives an `op://` ref (never a value). The agent
resolves via `op` if available, else asks in chat. Consistent with the secrets-in-git rule.

### Authoring vs consumption
- **Authoring** (your main machine): a clone. Edit `sources/…` and `PROVISION.md`,
  commit + push. No live-edit symlink — you edit in the repo, not in `~/.claude`.
- **Consumption** (any machine, incl. ephemeral): install Claude + log in + `gh auth login`,
  then "read `<URL>` and run it." No clone required; the agent pulls online.

### Multi-tool
Claude-first. Other agents self-provision by running the same prompt in them — each reads
its own current layout and places the same authored files where *it* loads them. Removes
the five-format translation that lived in `apply.sh`.

### Public baseline (rebuilt onto the model)
The public repo becomes a **public subset of the same model**, generated by
`publish-baseline.sh`:
- Authored files (the generic rules / agents / skills) — as today.
- A **public `PROVISION.md`** (baseline subset: superpowers/pr-review/commit/ponytail,
  meta-skills, context7 MCP, CLI tools) replacing the hard-coded phases in the old prompt.
- A **public master prompt** that reads the public `PROVISION.md`, needs no auth
  (fetches authored files by raw URL/tarball), and runs the same install/verify/prune loop.
- Modules (`google`, `web-stack`) stay as optional groups.

## What gets deleted / migrated
| Today | Becomes |
|---|---|
| `manifest/cli-tools.json`, `plugins.json`, `skill-lock.json`, `mcp.json` | consolidated into `PROVISION.md` (+ why + verify) |
| `scripts/apply.sh` | deleted — agent places authored files + installs |
| `scripts/capture.sh` | deleted — `PROVISION.md` is hand-curated; prune diff replaces reverse-drift |
| `OWNER-SETUP.md`, `STARTER-SETUP.md` | folded into `SETUP-PROMPT.md` (private) + public prompt |
| `baseline/install.sh` | deleted — prompt places authored files |
| authored `sources/*` | unchanged (canonical) |
| `publish-baseline.sh` | kept, updated to generate the public intent model |

## Risks & mitigations
- **Non-determinism / silent failure.** → Mandatory `verify` per item; prompt reports FAIL loudly.
- **Prune removes something you wanted.** → Per-item confirm; "adopt into PROVISION.md" is always an option.
- **Agent installs into the wrong place on a future tool version.** → That's the bet; verify catches a bad placement. If a category proves consistently fragile, its entry can carry an explicit hint.
- **Secrets.** → Names + `op://` refs only; values never in the repo.

## Out of scope (v1)
- Auto-generating `PROVISION.md` from live state (that would be `capture.sh` again).
- Non-Claude agents beyond "run the same prompt in them."
- Pinning versions (intent installs latest, as today).

## Success criteria (observable)
On a fresh machine: install Claude Code, log in, `gh auth login`, then paste/point the
master prompt. Result:
1. Every plugin / skill / MCP / CLI listed in `PROVISION.md` is installed, and its
   `verify` line passes.
2. Authored files (CLAUDE.md, rules, runbooks, own skills, own agents, hooks) are placed
   and loaded by Claude (e.g. `/memory` shows the rules; one hook fires).
3. Re-running after **removing** an entry from `PROVISION.md` (or a file from `sources/`)
   removes it live (after confirm).
4. No clone is required for consumption; a clone is used only for authoring.
```
</content>
