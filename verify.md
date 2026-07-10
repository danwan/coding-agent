# System Verification Prompt

You are tasked with verifying that the local system configuration and installed tools are fully aligned with the requirements defined in `PROVISION.md`. 

Run the verification steps below. For each individual item, print a single line in the format:
`[CATEGORY] <Item Name> — PASS`, `FAIL`, or `SKIP` (along with a brief reason or version if relevant).

---

## Step 0 — Identify the Environment
Establish and print:
* **Agent and Version:** Identify which agent you are and your version (`claude --version`, `agy --version`, etc.).
* **Operating System:** Report OS, version, architecture, and shell.

---

## Step 1 — Verify CLI Tools (Default Set)
Check if each of the following binaries is present and functioning by running its `--version`, `-v`, or `--help` command.
Report **PASS** with the version/path, or **FAIL**.

* **`git`** (git-scm.com)
* **`gh`** (GitHub CLI)
* **`rg`** (ripgrep)
* **`fd`** or **`fdfind`** (fdfind on Debian/Ubuntu with a symlink to `fd`)
* **`sg`** or **`ast-grep`** (ast-grep)
* **`jq`**
* **`tree`**
* **`tmux`**
* **`tailscale`**
* **`micro`** (micro text editor)
* **`uv`** (Astral uv)
* **`fnm`** (Fast Node Manager)
* **`bun`**
* **`op`** (1Password CLI)
* **`qmd`** (npm @tobilu/qmd)

---

## Step 2 — Verify Shell & Environment Configuration
Verify that the custom aliases, SSH tmux configuration, and Tailscale settings are correctly written and operational.

1. **Shell Aliases:** Check `~/.bashrc` or `~/.zshrc` for the active definition of:
   * `l` (should map to `ll` or `ls -alF`)
   * `la` (should map to `ls -A`)
   * `ll` (should map to `ls -alF`)
   * `ls` (should include `--color=auto`)
   * `grep`, `egrep`, `fgrep` (should include `--color=auto`)
   * `alert` (should include `notify-send --urgency=low ...` or equivalent desktop alert hook)
2. **SSH Tmux Auto-Load:** Check that `~/.bashrc` or `~/.zshrc` has an active script section starting a tmux session upon SSH connection. Specifically look for:
   * Checks on `SSH_CONNECTION` and starting `tmux attach-session` or `tmux new-session`.
3. **Tailscale SSH Enablement:**
   * Run `tailscale status` to confirm Tailscale is connected.
   * Check if Tailscale SSH is enabled on the client machine (e.g., check `sudo tailscale status` or verify if `--ssh` flag was passed during setup).

---

## Step 3 — Verify MCP Servers
Check if the following MCP servers are configured in your active config file (`~/.claude/settings.json` or `~/.gemini/config/mcp_config.json` depending on your agent type) and can be loaded:
* **`context7`** (remote URL: `https://mcp.context7.com/mcp`)
* **`google-developer-knowledge`** (remote URL: `https://developerknowledge.googleapis.com/mcp`)
* **`playwright`** (via `npx -y @playwright/mcp@latest`)

---

## Step 4 — Verify Authored Config & Rules
Verify that the global instruction files and Always-Loaded rules have been successfully translated and placed:
1. **Global Instructions:** Check if the global instruction file exists (`GEMINI.md` in your home directory if you are Antigravity, or `~/.claude/` / `CLAUDE.md` if you are Claude Code).
2. **Global Rules:** Verify that all canonical rule files from `sources/claude/rules/` in the repo have been copied into the agent's active rule subdirectory (e.g., `~/.gemini/config/rules/` or `~/.claude/rules/`).

---

## Step 5 — Report Synthesis
Output a final summary of results. If any item is marked **FAIL**, provide a short recommendation on how to remediate the discrepancy using the guidelines in `PROVISION.md` or the `ideas.md` improvement notes.
