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
  if [[ -f "$d" ]] && cmp -s "$s" "$d"; then
    same=$((same+1)); return 0
  fi
  changed=$((changed+1))
  if (( APPLY )); then
    mkdir -p "$(dirname "$d")"
    # Never clobber a symlink silently — replace it with a real file.
    [[ -L "$d" ]] && rm -f "$d"
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
  place_dir "$SRC/runbooks"   "$HOME/.claude/runbooks"
  place_dir "$SRC/agents"     "$HOME/.claude/agents"
  place_dir "$SRC/hooks"      "$HOME/.claude/hooks" '*.sh'
  (( APPLY )) && chmod +x "$HOME"/.claude/hooks/*.sh 2>/dev/null
fi

# ── Shared skill hub — every harness symlinks its skills out of here ─────────
head2 "Skill-Hub  ~/.agents"
if need "$HOME/.agents"; then
  # AGENTS.md is the harness-neutral name for the same content as CLAUDE.md.
  place "$SRC/CLAUDE.md" "$HOME/.agents/AGENTS.md"
  for d in "$REPO"/sources/skills/*/; do
    s="$d"; name="$(basename "$d")"
    # chrome-ui-explorer is Claude-only: it drives the Claude-in-Chrome
    # extension, which no other harness can talk to.
    [[ "$name" == "chrome-ui-explorer" ]] && continue
    for f in "$s"SKILL.md "$s"references/*.md "$s"scripts/*; do
      [[ -e "$f" ]] || continue
      place "$f" "$HOME/.agents/skills/$name/${f#$s}"
    done
  done
  place "$REPO/sources/skills/chrome-ui-explorer/SKILL.md" \
        "$HOME/.claude/skills/chrome-ui-explorer/SKILL.md"
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
  place_dir "$SRC/runbooks" "$HOME/.codex/runbooks"
  place_dir "$SRC/hooks"    "$HOME/.codex/hooks" '*.sh'
  (( APPLY )) && chmod +x "$HOME"/.codex/hooks/*.sh 2>/dev/null
  say "  note: Subagents werden von ./sync-agents.py verwaltet (Codex nutzt TOML)"
fi

# ── OpenCode — loads AGENTS.md + rules/*.md via its instructions array ───────
head2 "OpenCode  ~/.config/opencode"
if need "$HOME/.config/opencode"; then
  place     "$SRC/CLAUDE.md" "$HOME/.config/opencode/AGENTS.md"
  place_dir "$SRC/rules"     "$HOME/.config/opencode/rules"
  place_dir "$SRC/runbooks"  "$HOME/.config/opencode/runbooks"
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

# ── Cursor CLI ──────────────────────────────────────────────────────────────
# Cursor has no documented GLOBAL instruction file; ~/.cursor/rules/ is an
# undocumented path that this machine already uses (context7.mdc, convex_rules.mdc).
# Rules there must be .mdc WITH frontmatter — plain .md is silently ignored.
head2 "Cursor  ~/.cursor"
if need "$HOME/.cursor"; then
  for r in "$SRC/CLAUDE.md" "$SRC"/rules/*.md; do
    base="$(basename "$r" .md)"
    [[ "$base" == "CLAUDE" ]] && base="global-operating-rules"
    dst="$HOME/.cursor/rules/$base.mdc"
    place_str "$(printf -- '---\ndescription: %s\nalwaysApply: true\n---\n' "$base"; cat "$r")" "$dst"
  done
  say "  note: globaler Instruktionspfad ist bei Cursor undokumentiert — nach einem"
  say "        Cursor-Update prüfen, ob ~/.cursor/rules noch gelesen wird"
fi

# ── Factory Droid ───────────────────────────────────────────────────────────
# Droid searches ~/.factory/ AND ~/.agents/ for AGENTS.md, and also accepts
# CLAUDE.md. The hub copy above already reaches it; place the explicit one too.
head2 "Factory Droid  ~/.factory"
if need "$HOME/.factory"; then
  place "$SRC/CLAUDE.md" "$HOME/.factory/AGENTS.md"
fi

# ── Windsurf ────────────────────────────────────────────────────────────────
# global_rules.md is capped at 6000 characters and is the ONLY global surface —
# there is no global rules directory. Only CLAUDE.md fits; the rules stay out.
head2 "Windsurf  ~/.codeium/windsurf"
if need "$HOME/.codeium/windsurf"; then
  ws_size=$(wc -c < "$SRC/CLAUDE.md" | tr -d ' ')
  if (( ws_size > 6000 )); then
    say "  !! CLAUDE.md ist $ws_size B, Windsurf-Limit 6000 B — würde abgeschnitten. Übersprungen."
  else
    place "$SRC/CLAUDE.md" "$HOME/.codeium/windsurf/memories/global_rules.md"
    say "  ($ws_size/6000 B belegt; Rules passen dort nicht — Windsurf hat kein Rules-Verzeichnis)"
  fi
fi

head2 "Ergebnis"
say "  identisch: $same   zu schreiben: $changed   übersprungen: $skipped"
if (( ! APPLY )) && (( changed > 0 )); then
  say ""
  say "  Nichts geändert. Mit ./sync.sh --apply anwenden."
fi
exit 0
