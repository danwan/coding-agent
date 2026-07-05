# New `coding-agent` Public Repo — FINAL Implementation Plan (rev. 5)

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`).

**Goal:** Build ONE new, clean, public, Claude-focused repo `danwan/coding-agent` from the current setup's authored content + a new `PROVISION.md` (intent) + `SETUP-PROMPT.md` (pure prompt). No scripts, no hooks, no manifest, no mirror. The old repos and all local config stay untouched; migrating the live machine is a separate later step (Task 6).

**Architecture:** Assemble in a NEW dir `~/code/coding-agent` with fresh `.git`, copy authored files from `~/code/coding-agent-setup` (minus hooks/machinery), add the intent doc + prompt + docs, push to a new PUBLIC GitHub repo. A new machine installs Claude, then pastes the prompt; the agent reads `PROVISION.md` by raw URL and configures itself. Old `coding-agent-setup` (private) + `coding-agent-baseline` (public) + all symlinks: unchanged.

## Decisions locked (this session)
- **Repo:** `danwan/coding-agent`, **public**. Local dir `~/code/coding-agent`.
- **Scope:** Claude Code focused. Other tools' `sources/*` are stored (self-service), not in the default flow.
- **No hooks** — dropped entirely (incl. the secret-scan guardrail; the secrets rule now lives only as prompt/rule guidance).
- **Git = HTTPS** via `gh` (Golden Rule #2). The stale `sources/codex/AGENTS.md` "SSH only" line is reconciled to HTTPS on copy.
- **Prune:** always ask (remove or adopt), never auto-delete.
- **Secrets:** names + `op://` refs only (public-safe).
- Commit messages end `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

## The default / optional / module set (frozen)
- **Default — CLI tools:** git, gh, ripgrep, fd, ast-grep, jq, tree, tmux, uv, fnm, bun, op, qmd, skills
- **Default — MCP:** context7
- **Default — plugins:** superpowers, skill-creator, commit-commands, pr-review-toolkit, ponytail
- **Default — own skills:** branch-cleanup, challenge, code-search, git-sync, grill-me, security-review, pr-workflow
- **Default — remote meta-skills:** mcp-builder, find-skills
- **Default — authored:** CLAUDE.md, all rules, all runbooks
- **Optional (ask):** playwright MCP, memsearch (plugin + Python), coderabbit, frontend-design, typescript-lsp, pyright-lsp
- **Optional — `personal` toggle:** shell aliases, wezterm, settings.json (permissions/env/statusLine + statusline.sh) — kept out of default because permissions are personal/security-sensitive, not force-applied everywhere
- **Module `google` (ask):** google skills + agents-cli (`uvx google-agents-cli setup`) + google-developer-knowledge MCP
- **Module `webservice` (ask):** optional global plugins frontend-design/typescript-lsp; stack skills PROJECT-LOCAL (vercel-labs/agent-skills, vercel/next.js, waynesutton/convexskills; Modal via uv)
- **Project-local (later, per project):** convex, vercel, next, modal, webapp-testing, vitest

---

### Task 1: Scaffold `~/code/coding-agent` + copy authored content (old repo only READ)

- [ ] **Step 1: Create dir and copy authored content (minus hooks + machinery)**
```bash
OLD=~/code/coding-agent-setup ; NEW=~/code/coding-agent
mkdir -p "$NEW/sources"
# authored we keep:
cp -R "$OLD/sources/claude" "$NEW/sources/claude"
rm -rf "$NEW/sources/claude/hooks"            # hooks dropped entirely
cp -R "$OLD/sources/skills" "$NEW/sources/skills"
cp -R "$OLD/sources/codex" "$OLD/sources/opencode" "$OLD/sources/cursor" "$OLD/sources/antigravity" "$OLD/sources/shell" "$OLD/sources/wezterm" "$NEW/sources/"
cp -R "$OLD/docs" "$NEW/docs"
cp "$OLD/.gitignore" "$NEW/.gitignore"
# NOT copied: manifest/, baseline/, scripts/ (apply/capture/publish/convex-vercel), OWNER-SETUP.md, STARTER-SETUP.md, sources/claude/hooks/
```

- [ ] **Step 2: Strip hook wiring from the settings template** (hooks are gone; keep permissions/env/statusLine):
```bash
cd ~/code/coding-agent
jq 'del(.hooks)' sources/claude/settings.json.template > /tmp/s.json && mv /tmp/s.json sources/claude/settings.json.template
grep -q '"hooks"' sources/claude/settings.json.template && echo "WARN hooks still present" || echo "hooks stripped"
```

- [ ] **Step 3: Reconcile the Codex git rule to HTTPS** (removes the stale SSH-only conflict):
Edit `sources/codex/AGENTS.md` line with "Git → SSH only" → "Git → HTTPS to github.com via the gh credential helper, all git via CLI." Also update `sources/codex/runbooks/known-issues.md` note that referenced the SSH-only rule.
```bash
grep -rn 'SSH only\|SSH-only' sources/ || echo "no SSH-only left"
```
Expected: `no SSH-only left`.

- [ ] **Step 4: Confirm old repo untouched + new scaffold clean**
```bash
git -C ~/code/coding-agent-setup status --short   # expect empty
cd ~/code/coding-agent && test ! -e sources/claude/hooks && test ! -e manifest && test ! -e scripts && test ! -e baseline && ls sources && echo "clean scaffold"
```
Expected: empty old-status + `clean scaffold`.

- [ ] **Step 5: Fresh git init**
```bash
cd ~/code/coding-agent && git init -b main
```

---

### Task 2: Write `PROVISION.md`

- [ ] **Step 1: Write `~/code/coding-agent/PROVISION.md`** with this content:

```markdown
# PROVISION — Intent (Claude Code)

What this machine should have, from where, why, and how to verify. The master
prompt (SETUP-PROMPT.md) reads this and configures the agent using its current
knowledge — no install commands here. Secret NAMES + op:// refs only, never
values. Tags: [default] on every machine · [optional] ask · [module:x] grouped.

## CLI tools  [default]
git · gh · ripgrep (rg) · fd · ast-grep (sg) · jq · tree · tmux · uv · fnm · bun · op · qmd (npm @tobilu/qmd, never GitHub source) · skills (npx skills)
verify: each `--version` succeeds

## MCP servers
- context7  [default] — https://mcp.context7.com/mcp — why: current library docs — secret: CONTEXT7_API_KEY (op://Private/CONTEXT7_API_KEY/credential) — verify: server lists tools
- playwright  [optional] — npx @playwright/mcp@latest — why: headless browser — verify: agent can screenshot a page
- google-developer-knowledge  [module:google] — https://developerknowledge.googleapis.com/mcp — verify: server lists tools

## Plugins (Claude Code)
marketplaces: anthropics/claude-plugins-official, DietrichGebert/ponytail, zilliztech/memsearch
- superpowers  [default] — why: lifecycle process skills — verify: /plugin lists it
- skill-creator  [default] — why: author new skills — verify: /plugin lists it
- commit-commands  [default] — why: /commit, /commit-push-pr, /clean_gone — verify: /plugin lists it
- pr-review-toolkit  [default] — why: multi-agent PR review — verify: /plugin lists it
- ponytail  [default] — why: simplicity guardrail — verify: /plugin lists it
- memsearch  [optional] — why: cross-session memory recall (needs Python memsearch[onnx]) — verify: /plugin lists it
- coderabbit / frontend-design / typescript-lsp / pyright-lsp  [optional]

## Skills — own (stored in this repo; the prompt PLACES them)  [default]
branch-cleanup · challenge · code-search · git-sync · grill-me · security-review · pr-workflow
verify: `/` shows each; skills load

## Skills — remote meta (skills.sh)  [default]
- mcp-builder — anthropics/skills — verify: skills list shows it
- find-skills — vercel-labs/skills — verify: skills list shows it

## Module: google  [ask]
- google skills + agents-cli — `uvx google-agents-cli setup` (installs google-agents-cli-* skills globally; CLI-tied) — verify: agents-cli info
- google-developer-knowledge MCP (see MCP section)

## Module: webservice  [ask]  — mostly project-local
- optional global plugins: frontend-design, typescript-lsp
- stack SKILLS are PROJECT-LOCAL — inside each project: `npx skills add <source>` WITHOUT -g, commit .agents/ + skills-lock.json:
  vercel-labs/agent-skills · vercel/next.js · waynesutton/convexskills · (Modal: uv is in baseline)

## Authored config (placed from this repo)  [default]
- CLAUDE.md → the agent's global instruction file
- rules/ → where this agent reads global rules
- runbooks/ → referenced on demand (not auto-loaded)
(No hooks — by design.)

## Personal  [optional toggle]
- shell/aliases.zsh, wezterm/wezterm.lua → dotfiles
- settings.json (permissions, env, statusLine) + statusline.sh → Claude settings (permissions are personal; not applied unless chosen)

## Secrets
- CONTEXT7_API_KEY — op://Private/CONTEXT7_API_KEY/credential
- (REF_API_KEY, EXA_API_KEY are Cursor-only — not in the Claude default)
```

- [ ] **Step 2: Coverage check**
```bash
cd ~/code/coding-agent
for x in superpowers skill-creator commit-commands pr-review-toolkit ponytail branch-cleanup challenge code-search git-sync grill-me security-review pr-workflow mcp-builder find-skills context7 qmd skills; do grep -q "$x" PROVISION.md || echo "MISSING: $x"; done
grep -qi project-local PROVISION.md && echo "coverage check done" || echo "MISSING project-local"
```
Expected: only `coverage check done`.

---

### Task 3: Write `SETUP-PROMPT.md` (pure prompt)

- [ ] **Step 1: Write `~/code/coding-agent/SETUP-PROMPT.md`** — whole file = the prompt:

```
You are configuring THIS machine as my coding-agent setup (primarily Claude Code). Work autonomously and completely. Only stop to ask me for: a login you can't complete, a secret value, or a sudo password. Print one line per item — PASS, FAIL, or SKIP.

Source of truth (public — read the raw file directly, no clone needed):
https://raw.githubusercontent.com/danwan/coding-agent/main/PROVISION.md

Steps:

1. Read PROVISION.md at the URL above. Each item is tagged [default], [optional], or [module:x] and lists what, from where, why, and a one-line verify. It has NO install commands on purpose — you decide HOW. Read your own current documentation, check your version, and note anything specific about this OS and this agent. Do whatever is actually needed so each item works with your current version; if a mechanism changed since this doc was written, adapt — the intent is the contract, not any command.

2. Ask me which optional items and modules to add on top of the defaults: the [optional] entries (e.g. playwright, memsearch), the "personal" toggle (dotfiles + settings), and the modules "google" and/or "webservice". Wait for my answer. Install every [default] item plus whatever I pick.

3. Install each selected item from its source: CLI tools via this OS's package manager; plugins via their marketplace; skills via skills.sh; MCP servers into your MCP config. For any secret, resolve its op:// reference with the 1Password CLI if available, otherwise ask me — never write a secret value anywhere in a repo.

4. Place the authored config from "Authored config" (and "Personal" if chosen): fetch each file from this same repo by raw URL and put it where THIS version of the agent reads its global instructions, rules, runbooks, and skills. Determine every location from your own current docs, not any fixed path.

5. Run every selected item's verify line. Report PASS or FAIL for each.

6. Prune: list what is actually installed and placed, compare to the selected PROVISION.md items + authored set, and for anything present but not listed ask me whether to remove it or add it to PROVISION.md. Never delete without asking.

7. Report what you installed, placed, verified, and pruned, and anything you couldn't finish.
```

- [ ] **Step 2: Purity + URL check**
```bash
cd ~/code/coding-agent
head -1 SETUP-PROMPT.md | grep -q '^You are configuring' && echo "pure start"
grep -q 'raw.githubusercontent.com/danwan/coding-agent/main/PROVISION.md' SETUP-PROMPT.md && echo "raw URL as text"
grep -qE '^\s*#|^```|Copy everything' SETUP-PROMPT.md && echo "WARN wrapper" || echo "no wrapper"
for n in 1 2 3 4 5 6 7; do grep -q "^$n\." SETUP-PROMPT.md || echo "MISSING step $n"; done
echo "prompt check done"
```
Expected: `pure start`, `raw URL as text`, `no wrapper`, no MISSING, `prompt check done`.

---

### Task 4: Docs + snapshot secret-scan + create & push the public repo

- [ ] **Step 1: Write `README.md` + `AGENTS.md`** for the new repo. README layout: PROVISION.md (intent), SETUP-PROMPT.md (the paste prompt), sources/ (authored + dotfiles), docs/. State: public, no scripts, no hooks, provisioned by prompt, secrets never in repo. AGENTS.md: PROVISION.md is source of truth; agent provisions from it; prune asks; HTTPS. Symlink `CLAUDE.md -> AGENTS.md` if wanted.

- [ ] **Step 2: Secret-scan the snapshot** (fail on any match, no truncation; op:// refs are safe):
```bash
cd ~/code/coding-agent
if command -v gitleaks >/dev/null; then gitleaks detect --no-git --source . --redact -v; echo "gitleaks exit: $?"; \
else grep -rnEI 'BEGIN (RSA|OPENSSH|EC|PGP) PRIVATE KEY|xox[baprs]-|sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{36}|AKIA[0-9A-Z]{16}' --exclude-dir=.git . && echo "MATCHES — STOP" || echo "grep scan clean"; fi
```
Any real match → STOP, do not push.

- [ ] **Step 3: Initial commit + create the public repo + push**
```bash
cd ~/code/coding-agent
git add -A
git commit -m "Initial commit — intent-based Claude Code setup

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
gh repo create danwan/coding-agent --public --source . --remote origin --push
gh repo view danwan/coding-agent --json visibility -q .visibility   # expect PUBLIC
```

---

### Task 5: Verify the new repo + confirm nothing old changed

- [ ] **Step 1: Raw URLs readable (no auth)**
```bash
curl -fsSL --max-time 10 https://raw.githubusercontent.com/danwan/coding-agent/main/PROVISION.md | head -3
curl -fsSL --max-time 10 https://raw.githubusercontent.com/danwan/coding-agent/main/SETUP-PROMPT.md | head -1
```
Expected: PROVISION.md head + the prompt's first line.

- [ ] **Step 2: Old repos + local config untouched (the safety invariant)**
```bash
git -C ~/code/coding-agent-setup status --short          # expect empty
./scripts/apply.sh --check 2>/dev/null | tail -1 || true  # (run from old repo) expect: 0 pending / 0 todo — still green
gh repo view danwan/coding-agent-setup --json visibility -q .visibility     # expect PRIVATE
gh repo view danwan/coding-agent-baseline --json isArchived -q .isArchived  # expect false
for l in ~/.claude/CLAUDE.md ~/.codex/AGENTS.md ~/.config/opencode/AGENTS.md ~/.cursor/rules ~/.gemini/GEMINI.md; do
  case "$(readlink "$l")" in */coding-agent-setup/*) [ -e "$l" ] && echo "OK(old) $l" || echo "BROKEN $l";; *) echo "? $l";; esac
done
```
Expected: old status empty + apply.sh --check green + PRIVATE + not-archived + every symlink still resolves into the OLD path.

- [ ] **Step 3: SCRATCH TEST (the point of this plan).** Throwaway `CLAUDE_HOME` (default) or a spare machine/VM. In a fresh Claude session, paste `SETUP-PROMPT.md`. Confirm: reads PROVISION.md from the new raw URL, asks the optional/module question, installs the defaults, places authored files, verify lines pass. Iterate on PROVISION.md/SETUP-PROMPT.md in `~/code/coding-agent` (commit + push) until clean. **Claude is the mandatory agent; Codex/OpenCode/Cursor/Antigravity opportunistically/later.** No time pressure — the old setup runs untouched throughout.

- [ ] **Step 4: Done-definition (all must hold):** new repo exists locally + on GitHub (PUBLIC); raw PROVISION.md + SETUP-PROMPT.md reachable; scratch test passes in ≥1 fresh Claude/home; old local config unchanged; old `coding-agent-setup ./scripts/apply.sh --check` still green.

---

### Task 6 (DEFERRED — separate, user-triggered, NOT part of this build): migrate local + retire old

Only after Task 5 satisfies you. Its own checklist later.
- Repoint live symlinks from `~/code/coding-agent-setup/sources/...` to `~/code/coding-agent/sources/...` (or relocate the new repo into the old path).
- Inventory `~/.gemini/**` (active vs historical vs prune-candidate); prune with confirm.
- Archive `danwan/coding-agent-baseline`; archive then (later, confident) delete `danwan/coding-agent-setup`. Keep backups until then.

---

## Non-Goals (must NOT go in the new repo)
Secret VALUES · auth/logins/tokens · caches, logs, sessions, histories, DBs · `.DS_Store`/`.idea/`/`.memsearch/` · **all hooks** · the old machinery (`manifest/`, `baseline/`, `apply.sh`/`capture.sh`/`publish-baseline.sh`) · `scripts/convex-vercel/` · project-specific/stack skills (convex/vercel/next/modal → project-local) · `~/.gemini` backup/IDE/state dirs.

## Testing philosophy
Static checks (coverage grep, prompt purity, raw-URL curl) + the "old untouched" invariant + the real scratch-machine test. Nothing local is modified while building/testing → no rollback risk; the live migration (Task 6) is a separate later decision.
```
</content>
