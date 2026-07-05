---
name: config-edit
description: Reference for Claude Code path syntax in settings.json and hooks. Use when configuring permissions, sandbox restrictions (read/write allowlists, deny rules), hook execution paths, or any settings that require directory patterns (~/path, //absolute, /relative).
allowed-tools: Read, Edit, Write, Glob, Grep
version: 1.0.0
effort: low
---

# Claude Code Path Syntax (settings.json)

Path patterns in `~/.claude/settings.json` follow gitignore-style conventions with special prefixes:

| Pattern | Meaning | Example |
|---------|---------|---------|
| `//path` | **Absolute** path from filesystem root | `//Users/alice/Code` → `/Users/alice/Code` |
| `~/path` | Path from **home** directory | `~/Documents` → `/Users/alice/Documents` |
| `/path` | Path **relative to settings file** | `/src` → `~/.claude/src` |
| `path` | Path **relative to current directory** | `*.env` → `<cwd>/*.env` |

## Critical Gotcha

A single `/` is **NOT** an absolute path — use `//` for absolute paths.

```json
// Correct — absolute paths
"Read(//Users/alice/**)"
"//tmp/build"

// Correct — home-relative (preferred for portability)
"~/code/**"

// Wrong — these are relative to settings file location
"Read(/Users/alice/**)"
"/tmp/build"
```

This applies to both `permissions.allow` rules and `sandbox.filesystem` allowlists.

## Sandbox Filesystem Format

The correct settings.json key for sandbox write restrictions is `allowWrite` (flat array):

```json
"sandbox": {
  "filesystem": {
    "allowWrite": ["~/code/**", "//tmp/**"]
  }
}
```

Do NOT use `write.allowOnly` — that is the runtime sandbox format, not the settings input format.

Additional options: `denyWrite`, `denyRead` (same path syntax).
