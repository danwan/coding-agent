#!/usr/bin/env bash
# Place this repo's authored content into every installed coding agent.
#
#   ./sync.sh          # show what would change, touch nothing
#   ./sync.sh --apply  # write it
#
# The repo is the source of truth; harnesses get COPIES, never symlinks into
# here. A symlink would make `git checkout <old-branch>` silently rewrite every
# agent's global instructions, and would break all of them if the repo moved.
# Copies drift only because nobody syncs them — that is what this script is for.
#
# Every harness that is not installed is skipped, not an error.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO/sources/claude"
APPLY=0
[[ "${1:-}" == "--apply" ]] && APPLY=1

changed=0; same=0; skipped=0

say()  { printf '%s\n' "$*"; }
head2() { printf '\n\033[1m%s\033[0m\n' "$*"; }

# place <source-file> <destination-file>
place() {
  local s="$1" d="$2"
  [[ -f "$s" ]] || { say "  !! Quelle fehlt: ${s#$REPO/}"; return 1; }
  # A symlink into this repo must be replaced by a real copy — and it has to be
  # caught BEFORE the cmp below, because a link to the source compares equal to
  # itself and would be reported as "identisch" forever. That is exactly how
  # ~/.config/opencode kept a live link into the repo unnoticed until 2026-08-01.
  if [[ -L "$d" ]]; then
    changed=$((changed+1))
    if (( APPLY )); then
      rm -f "$d" && cp "$s" "$d" && say "  ~> ${d/#$HOME/\~} (Symlink durch Kopie ersetzt)"
    else
      say "  would replace symlink ${d/#$HOME/\~} -> $(readlink "$d")"
    fi
    return 0
  fi
  if [[ -f "$d" ]] && cmp -s "$s" "$d"; then
    same=$((same+1)); return 0
  fi
  changed=$((changed+1))
  if (( APPLY )); then
    mkdir -p "$(dirname "$d")"
    cp "$s" "$d" && say "  ~> ${d/#$HOME/\~}"
  else
    say "  would write ${d/#$HOME/\~}"
  fi
}

# place_str <content> <destination-file>
# Same contract as place(), for content assembled in memory. Avoids mktemp,
# which cannot write to the system temp dir under the agent sandbox.
place_str() {
  local content="$1" d="$2"
  if [[ -f "$d" ]] && [[ "$content" == "$(cat "$d")" ]]; then
    same=$((same+1)); return 0
  fi
  changed=$((changed+1))
  if (( APPLY )); then
    mkdir -p "$(dirname "$d")"
    [[ -L "$d" ]] && rm -f "$d"
    printf '%s\n' "$content" > "$d" && say "  ~> ${d/#$HOME/\~}"
  else
    say "  would write ${d/#$HOME/\~}"
  fi
}

# place_block <marker> <source-file> <destination-file>
# Replaces the region between <!-- marker --> … <!-- marker --> and leaves the
# rest of the file alone. Gemini's GEMINI.md carries plugin-managed blocks
# (context7, house-rules) that a plain overwrite would destroy.
place_block() {
  local marker="$1" s="$2" d="$3"
  [[ -f "$s" ]] || { say "  !! Quelle fehlt: ${s#$REPO/}"; return 1; }
  local new
  new="$(MARKER="$marker" SRC_FILE="$s" DEST="$d" python3 - <<'PY'
import os, pathlib, re
marker, src, dest = os.environ['MARKER'], os.environ['SRC_FILE'], os.environ['DEST']
body = pathlib.Path(src).read_text().rstrip()
block = f"<!-- {marker} -->\n{body}\n<!-- {marker} -->"
old = pathlib.Path(dest).read_text() if os.path.exists(dest) else ""
pat = re.compile(rf"<!-- {re.escape(marker)} -->.*?<!-- {re.escape(marker)} -->", re.S)
out = pat.sub(lambda _: block, old) if pat.search(old) else (old.rstrip() + "\n\n" + block + "\n")
print(out, end="")
PY
)" || return 1
  if [[ -f "$d" ]] && [[ "$new" == "$(cat "$d")" ]]; then
    same=$((same+1)); return 0
  fi
  changed=$((changed+1))
  if (( APPLY )); then
    mkdir -p "$(dirname "$d")"
    printf '%s' "$new" > "$d" && say "  ~> ${d/#$HOME/\~} (Block: $marker)"
  else
    say "  would update ${d/#$HOME/\~} (Block: $marker, andere Blöcke bleiben)"
  fi
}

# place_dir <source-dir> <destination-dir> [glob]
place_dir() {
  local sd="$1" dd="$2" glob="${3:-*.md}"
  [[ -d "$sd" ]] || return 0
  # A linked destination DIRECTORY is worse than a linked file: every write below
  # would land back inside this repo. Break the link before placing anything.
  if [[ -L "$dd" ]]; then
    changed=$((changed+1))
    if (( APPLY )); then
      rm -f "$dd" && mkdir -p "$dd" && say "  ~> ${dd/#$HOME/\~}/ (Symlink-Verzeichnis durch echtes ersetzt)"
    else
      say "  would replace symlinked dir ${dd/#$HOME/\~} -> $(readlink "$dd")"
      return 0
    fi
  fi
  local f
  for f in "$sd"/$glob; do
    [[ -e "$f" ]] || continue
    place "$f" "$dd/$(basename "$f")"
  done
}

need() { [[ -d "$1" ]] || { skipped=$((skipped+1)); say "  (nicht installiert — übersprungen)"; return 1; }; }

# ── Claude Code — the reference implementation ───────────────────────────────
head2 "Claude Code  ~/.claude"
if need "$HOME/.claude"; then
  place     "$SRC/CLAUDE.md"  "$HOME/.claude/CLAUDE.md"
  place_dir "$SRC/rules"      "$HOME/.claude/rules"
  place_dir "$SRC/agents"     "$HOME/.claude/agents"
fi

# ── Shared skill hub — every harness symlinks its skills out of here ─────────
head2 "Skill-Hub  ~/.agents"
if need "$HOME/.agents"; then
  # AGENTS.md is the harness-neutral name for the same content as CLAUDE.md.
  place "$SRC/CLAUDE.md" "$HOME/.agents/AGENTS.md"
  for d in "$REPO"/sources/skills/*/; do
    s="$d"; name="$(basename "$d")"
    for f in "$s"SKILL.md "$s"references/*.md "$s"scripts/*; do
      [[ -e "$f" ]] || continue
      place "$f" "$HOME/.agents/skills/$name/${f#$s}"
    done
  done
  # Document templates (ADR, feature spec). Harness-neutral, so they live in the
  # hub under one path every agent can reference; search-discipline.md points here.
  place_dir "$SRC/templates" "$HOME/.agents/templates"
fi

# ── Codex — same content, its own filenames ─────────────────────────────────
# Codex reads ~/.codex/AGENTS.md. It has no rules-glob, so the rules are
# concatenated into that one file; ~/.codex/rules/ is kept as the on-demand
# copy that the inlined text points at.
head2 "Codex  ~/.codex"
if need "$HOME/.codex"; then
  codex_doc="$(cat "$SRC/CLAUDE.md"; for r in "$SRC"/rules/*.md; do printf '\n\n---\n\n'; cat "$r"; done)"
  # Codex truncates its project doc at project_doc_max_bytes (default 65536).
  # Silently losing the tail of the rules would be invisible, so check.
  codex_limit=$(python3 -c "
import tomllib,sys
try: print(tomllib.load(open('$HOME/.codex/config.toml','rb')).get('project_doc_max_bytes',65536))
except Exception: print(65536)")
  codex_size=${#codex_doc}
  if (( codex_size > codex_limit )); then
    say "  !! AGENTS.md wäre $codex_size B, Limit ist $codex_limit B — Codex würde abschneiden. Übersprungen."
  else
    place_str "$codex_doc" "$HOME/.codex/AGENTS.md"
  fi
  place_dir "$SRC/rules"    "$HOME/.codex/rules"
  say "  note: Subagents werden von ./sync-agents.py verwaltet (Codex nutzt TOML)"
fi

# ── OpenCode — loads AGENTS.md + rules/*.md via its instructions array ───────
head2 "OpenCode  ~/.config/opencode"
if need "$HOME/.config/opencode"; then
  place     "$SRC/CLAUDE.md" "$HOME/.config/opencode/AGENTS.md"
  place_dir "$SRC/rules"     "$HOME/.config/opencode/rules"
  # Subagents are NOT copied raw here — their frontmatter differs per harness.
  # ./sync-agents.py owns every agents/ directory.
fi

# ── Gemini / Antigravity ────────────────────────────────────────────────────
head2 "Antigravity / Gemini  ~/.gemini"
if need "$HOME/.gemini"; then
  # GEMINI.md carries plugin-managed blocks (context7, house-rules) — merge into
  # our own marked block instead of overwriting the file.
  place_block "global-operating-rules" "$SRC/CLAUDE.md" "$HOME/.gemini/GEMINI.md"
  place_dir "$SRC/rules" "$HOME/.gemini/antigravity-cli/plugins/house-rules/rules"
fi

# ── Grok ────────────────────────────────────────────────────────────────────
# Nothing is placed here ON PURPOSE. Grok's [compat.claude] reads ~/.claude/
# directly — CLAUDE.md, rules/, skills/ and the settings permissions — so a copy
# under ~/.grok/rules/ would load every rule TWICE. Verify with `grok inspect`:
# the authored rules must appear tagged [claude], and ~/.grok/rules/ stay empty.
head2 "Grok  ~/.grok"
if need "$HOME/.grok"; then
  if [[ -n "$(ls -A "$HOME/.grok/rules" 2>/dev/null)" ]]; then
    say "  !! ~/.grok/rules/ ist nicht leer — Regeln laden doppelt (siehe grok.md)"
  else
    say "  erbt ~/.claude via [compat.claude] — nichts zu platzieren"
    same=$((same+1))
  fi
fi

head2 "Ergebnis"
say "  identisch: $same   zu schreiben: $changed   übersprungen: $skipped"
if (( ! APPLY )) && (( changed > 0 )); then
  say ""
  say "  Nichts geändert. Mit ./sync.sh --apply anwenden."
fi
exit 0
