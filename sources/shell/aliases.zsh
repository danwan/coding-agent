# ============================================================
# Shell aliases — canonical source of truth for the agent alias block.
# ============================================================
# This file documents the alias block that lives at the top of ~/.zshrc.
# ~/.zshrc is NOT symlinked into this repo (it also carries installer-
# appended content from Antigravity, grok, fnm, zoxide, fzf), so the
# alias block is mirrored here by hand. When you add/change an alias,
# update BOTH this file and the live ~/.zshrc so they stay in sync.
#
# Convention: one-letter / two-letter aliases for the coding agents,
# grouped by tool. `o`-family = OpenCode, `c`-family = Claude Code,
# `co`-family = Codex.

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

# === Git ===
alias gst='git fetch --all --prune && gh pr status'
alias gwl='git worktree list'
alias gwprune='git worktree prune && git branch --merged | grep -v "\*\|main\|master" | xargs -r git branch -d'

# === Codex CLI ===
alias co='codex'
alias coo='codex --dangerously-bypass-approvals-and-sandbox'

# === OpenCode ===
alias op='opencode'
