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
