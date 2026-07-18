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
alias co='codex'
alias coo='codex --dangerously-bypass-approvals-and-sandbox'

# === OpenCode ===
alias oc='opencode'

# === 1Password (op = the 1Password CLI binary, NOT an alias) ===
# Service-account token from the macOS Keychain (~10ms). Basis for
# `op run` / `op read` in all projects. No secret values here — the
# token lives only in the Keychain.
export OP_SERVICE_ACCOUNT_TOKEN="$(security find-generic-password -s op-service-account -a 1password -w 2>/dev/null)"

# Greptile MCP API key -> op://APIKeys/greptile/credential
# Only Claude Code needs it. `op read` costs ~1.8s (network), so it is
# resolved at Claude start instead of globally in every shell.
claude() {
  local key
  key="$(op read op://APIKeys/greptile/credential 2>/dev/null)"
  if [[ -z "$key" ]]; then
    print -u2 "claude: greptile key nicht aus 1Password lesbar -> starte ohne Greptile"
    command claude "$@"
    return
  fi
  GREPTILE_API_KEY="$key" command claude "$@"
}
