# ============================================================
# Shell aliases — canonical source of truth for the agent alias block.
# ============================================================
# This file documents the alias/function block that lives in ~/.zshrc.
# ~/.zshrc is NOT symlinked into this repo (it also carries installer-
# appended content from Antigravity, grok, fnm, zoxide, fzf), so the
# block is mirrored here by hand. When you add/change an alias,
# update BOTH this file and the live ~/.zshrc so they stay in sync.
#
# Convention: one-letter / two-letter aliases for the coding agents,
# grouped by tool. `c`-family = Claude Code, `co`-family = Codex,
# `oc` = OpenCode. `op` is RESERVED for the 1Password CLI (it was the
# OpenCode alias until 2026-07; renamed to `oc` when the 1Password CLI
# took over the `op` binary name).

# === General ===
alias l='pwd && echo && ls -lA'
alias p='pwd'
alias m='micro'
alias x='cd ..'

# === Claude Code ===
alias c='claude --remote-control'
alias cc='claude --dangerously-skip-permissions --remote-control'
alias ca='claude agents'
alias cao='claude agents --dangerously-skip-permissions'

claude-check() {
    echo "Project: $(basename $(pwd))"
    [ -f "CLAUDE.md" ] && echo "✓ CLAUDE.md" || echo "✗ CLAUDE.md"
    [ -f "TROUBLESHOOTING.md" ] && echo "✓ TROUBLESHOOTING.md" || echo "○ TROUBLESHOOTING.md"
    [ -d ".claude" ] && echo "✓ .claude/" || echo "○ .claude/"
}

# === Git ===
alias gst='git fetch --all --prune && gh pr status'
alias gwl='git worktree list'
alias gwprune='git worktree prune && git branch --merged | grep -v "\*\|main\|master" | xargs -r git branch -d'

# === Codex CLI ===
# Context7 MCP key, same source as the opencode wrapper below.
# NOTE: Codex's shell-environment policy strips *KEY*/*SECRET*/*TOKEN* from the
# inherited environment by default, so exporting this globally would not reach a
# shell command anyway — it is passed to the codex process itself, which then
# hands it to the MCP server via env_http_headers.
codex() {
  local key
  key="$(op read op://APIKeys/context7/credential 2>/dev/null)"
  if [[ -z "$key" ]]; then
    print -u2 "codex: context7 key nicht aus 1Password lesbar -> Start abgebrochen"
    return 1
  fi
  CONTEXT7_API_KEY="$key" command codex "$@"
}
alias co='codex'
alias coo='codex --dangerously-bypass-approvals-and-sandbox'

# === OpenCode ===
# Context7 MCP API key -> op://APIKeys/context7/credential.
# opencode.json references it as {env:CONTEXT7_API_KEY}. That substitution
# resolves a MISSING variable to the empty string rather than failing, so a
# broken key would show up as Context7 silently answering nothing. Hence the
# explicit check here — fail loud instead.
opencode() {
  local key
  key="$(op read op://APIKeys/context7/credential 2>/dev/null)"
  if [[ -z "$key" ]]; then
    # opencode substitutes a MISSING variable with the empty string instead of
    # erroring, so an unauthenticated Context7 would look like a working one.
    print -u2 "opencode: context7 key nicht aus 1Password lesbar -> Start abgebrochen"
    return 1
  fi
  CONTEXT7_API_KEY="$key" command opencode "$@"
}
alias oc='opencode'

# === 1Password (op = the 1Password CLI binary, NOT an alias) ===
# Service-account token from the macOS Keychain (~10ms). Basis for
# `op run` / `op read` in all projects. No secret values here — the
# token lives only in the Keychain.
export OP_SERVICE_ACCOUNT_TOKEN="$(security find-generic-password -s op-service-account -a 1password -w 2>/dev/null)"

# Context7 MCP API key from 1Password. Resolved at Claude startup instead of
# persisted in ~/.claude.json.
claude() {
  local context7_key
  context7_key="$(op read op://APIKeys/context7/credential 2>/dev/null)"
  if [[ -z "$context7_key" ]]; then
    print -u2 "claude: context7 key nicht aus 1Password lesbar -> Start abgebrochen"
    return 1
  fi
  # GREPTILE_API_KEY explicitly cleared, not just omitted: Greptile is out of
  # scope (see PROVISION.md), and an exported value in the parent shell would
  # otherwise silently re-enable it in the child.
  CONTEXT7_API_KEY="$context7_key" GREPTILE_API_KEY= command claude "$@"
}
