You are configuring THIS machine as my coding-agent setup. You may be Claude
Code, Codex, OpenCode, Antigravity, Cursor, or another coding agent — figure out
which you are and adapt. Work autonomously and completely. Only stop to ask me
for: a login you can't complete, a secret value, or a sudo password. Print one
line per item — PASS, FAIL, or SKIP.

Source of truth (public — read the raw files directly, no clone needed):
- Intent:  https://raw.githubusercontent.com/danwan/coding-agent/main/PROVISION.md
- Authored files + notes live under the same repo at
  `https://raw.githubusercontent.com/danwan/coding-agent/main/<path>`
  (e.g. `sources/claude/CLAUDE.md`). Browse paths with `gh api` or the raw URLs.

The repo stores everything **once**, in Claude Code's format, under
`sources/claude/` (+ own skills under `sources/skills/`). It is the single source
of truth. If you are not Claude Code, you translate those files into your own
format — you know your own layout better than any frozen script could. The intent
is the contract, not any specific command or path.

## Step 0 — Identify yourself and this machine
Establish, and print, before doing anything else:
- **Which agent am I** (Claude Code / Codex / OpenCode / Antigravity / Cursor / other) **and what version?** (`<tool> --version`, `--help`, or your about/info.)
- **What OS, distro, version, and architecture** is this? Which **shell**? Which **package manager** is available (brew / apt / dnf / pacman / winget / scoop / …)?
- **What language is the user using** (from this prompt / their locale)? Report and interact in it.

## Step 1 — Learn your OWN current layout (do not assume fixed paths)
Read your own current documentation (`--help`, official docs, or Context7) and
determine, for THIS version of you:
- Where your **global instruction file** lives and what it's called.
- How you load **rules**, **subagents/agents**, **skills**, **MCP servers**, **plugins**, and **settings** — file names, formats, directories.
- Your **config file** path and format.
Write down the concrete target for each before you place anything.

## Step 2 — Read the intent
Read `PROVISION.md`. Each item is tagged `[default]`, `[optional]`, or
`[module:x]` and lists what · from where · why · a one-line verify. It has **no
install commands on purpose** — you decide HOW, using the mechanism current for
your version. If a mechanism changed since this doc was written, adapt.

## Step 3 — Ask which optional items and modules to add
On top of the `[default]` set, ask me about: the `[optional]` entries (e.g.
playwright, memsearch), the "personal" toggle (dotfiles + settings), and the
modules `google` and/or `webservice`.

Additionally, if you are not running as Claude Code and need to translate the configurations for another target format, ask me to select between:
- **OpenCode**
- **Codex**

Ask about each separately, but enforce that only one of these two options can be selected. Wait for my answer.

## Step 4 — Place the authored config (translate to YOUR format)
Fetch the canonical files from the repo and place each where THIS version of you
loads it (the targets you found in Step 1):
- `sources/claude/CLAUDE.md` → your global instruction file.
- `sources/claude/rules/` → your always-loaded rules. Copy **all** of them —
  never silently drop one.
- `sources/claude/runbooks/` → your consult-on-demand references.
- `sources/claude/agents/` → your subagent definitions.
- own skills from `sources/skills/` → the shared `~/.agents/skills/` hub, linked
  into your skills dir (Claude reads them natively). Place the `[default]`
  own-skills; add the `[optional]` ones only if selected in Step 3 — see
  `PROVISION.md`'s "Skills — own" sections for which is which.
- If "personal" was chosen: `sources/claude/settings.json.template`,
  `sources/claude/statusline.sh`, and the dotfiles under `sources/shell/`,
  `sources/wezterm/`.

**If you are NOT Claude Code**, also read your harness note first and translate
per its mapping — it carries only what you can't derive (format mapping + which
Claude features to skip):
- Codex → `sources/harness-notes/codex.md`
- OpenCode → `sources/harness-notes/opencode.md`
- Antigravity → `sources/harness-notes/antigravity.md`
- Cursor → `sources/harness-notes/cursor.md`

Keep instruction **bodies verbatim**; only translate frontmatter/format and skip
features your harness genuinely has no equivalent for (say so as SKIP).

## Step 5 — Install the selected intent items
Install each with the mechanism current for your version: CLI tools via this OS's
package manager (use the canonical package/source named in `PROVISION.md` — the
binary name alone is often ambiguous across OSes); plugins via their marketplace;
skills via skills.sh; MCP servers into your MCP config. For any secret, resolve
its `op://` reference with the 1Password CLI if available, otherwise ask me —
never write a secret value anywhere in a repo.

## Step 6 — Verify
Run every selected item's verify line. Report PASS or FAIL for each.

## Step 7 — Prune (ask, never auto-delete)
List what is actually installed and placed, compare to the selected `PROVISION.md`
items + authored set, and for anything present but not listed ask me whether to
remove it or add it to `PROVISION.md`. Never delete without asking.

## Step 8 — Report
Report what you detected (Step 0), installed, placed (and translated), verified,
and pruned — plus anything you couldn't finish and why.
