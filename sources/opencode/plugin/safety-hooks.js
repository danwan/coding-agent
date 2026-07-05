// OpenCode safety-hooks plugin — translates the two Claude Code PreToolUse
// hooks into OpenCode's plugin Hook surface.
//
// Reuses the canonical shell scripts under ~/.claude/hooks/ (claude is master
// for shared authored config — see sources/opencode/README.md) so the secret
// patterns and deploy-gate logic live in exactly one place. This file is only
// the thin adapter that bridges OpenCode's tool.execute.before hook to the
// scripts' stdin-JSON / exit-code contract.
//
// Block = throw new Error(...)  (confirmed viable — see the env-protection.js
// example in opencode's plugin docs, which throws to block a .env read).
//
// Wired in opencode.json via:  "plugin": ["./plugin/safety-hooks.js"]
// (~/.config/opencode/plugin symlinks to sources/opencode/plugin, so the ./
//  path resolves through the symlink into this repo file.)

import { spawnSync } from "node:child_process"
import { homedir } from "node:os"
import path from "node:path"

const HOOKS_DIR = path.join(homedir(), ".claude", "hooks")

function bashCommand(args) {
  if (args && typeof args.command === "string") return args.command
  if (args && Array.isArray(args.commands)) return args.commands.join(" ")
  return ""
}

function runScript(scriptPath, claudeStdinJson) {
  // The scripts read stdin as JSON: {"tool_input":{"command":"..."}} and use
  // exit 2 to block (pre-publish-secret-scan.sh) or emit a JSON verdict
  // (check-backend-deploy.sh). We synthesize the Claude-stdin shape so the
  // scripts run unmodified.
  return spawnSync("bash", [scriptPath], {
    input: JSON.stringify(claudeStdinJson),
    encoding: "utf8",
    timeout: 10000,
  })
}

export default async () => {
  return {
    "tool.execute.before": async (input, output) => {
      if (input.tool !== "bash") return
      const cmd = bashCommand(output.args)
      if (!cmd) return

      // 1. Secret scan — the script self-scopes to the publish surface via its
      //    own TRIGGER_REGEX (git commit/tag/branch + gh pr/issue/gist/release),
      //    so it is safe to call on every bash command. exit != 0 => block.
      const scan = runScript(path.join(HOOKS_DIR, "pre-publish-secret-scan.sh"), {
        tool_input: { command: cmd },
      })
      if (scan.status !== 0) {
        throw new Error(
          `pre-publish-secret-scan blocked this command:\n` +
            (scan.stderr || scan.stdout || "no output") +
            `\n\nReference: ~/.claude/rules/secrets-in-git.md`
        )
      }

      // 2. Backend deploy check — the script does NOT self-scope by command, so
      //    pre-filter to git push only (mirrors Claude's `if: Bash(git push*)`).
      //    result "warn" => surface to stderr and proceed; non-zero => block.
      if (/(^|\s)git\s+push(\s|$)/.test(cmd)) {
        const dep = runScript(path.join(HOOKS_DIR, "check-backend-deploy.sh"), {
          tool_input: { command: cmd },
        })
        if (dep.status !== 0) {
          throw new Error(
            `check-backend-deploy blocked:\n` + (dep.stderr || dep.stdout || "no output")
          )
        }
        if (dep.stdout && dep.stdout.includes('"warn"')) {
          process.stderr.write(`\n${dep.stdout}\n`)
        }
      }
    },
  }
}
