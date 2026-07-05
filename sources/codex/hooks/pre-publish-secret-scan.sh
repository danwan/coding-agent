#!/bin/bash
# PreToolUse hook: block secret leaks in outgoing-publish-to-GitHub-or-git surface.
# Scope: text the agent itself authors via Bash → commit/tag annotations,
#        PR/issue/gist/release bodies, branch names.
# NOT a working-tree gitleaks replacement.
# Reference rule: ~/.codex/rules/secrets-in-git.md

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$CMD" ]] && exit 0

# Codex permission-deny parity for Codex permissions.deny.
if printf '%s' "$CMD" | grep -Eq '(^|[;&|[:space:]])rm[[:space:]]+-rf([[:space:]]|$)|(^|[;&|[:space:]])rm[[:space:]]+-r([[:space:]]|$)|(^|[;&|[:space:]])sudo([[:space:]]|$)|(^|[;&|[:space:]])chmod[[:space:]]+777([[:space:]]|$)'; then
  echo "Blocked by Codex permission parity: command matches Codex deny policy." >&2
  exit 2
fi

# Audit log — append-only, BLOCK + OVERRIDE only (APPROVE skipped to avoid spam).
# By design we log NO body content: just command type (first 40 chars, newlines stripped)
# and the matched pattern names. A blocked secret value must never end up in the log.
LOG_FILE="$HOME/.codex/logs/pre-publish-secret-scan.log"
log_event() {
  local verdict="$1" detail="$2"
  mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || return 0
  local ts cmd_type
  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  # Build a sanitized cmd_type: strip everything after the first quote (body content),
  # AND replace any unquoted arg after a body/value-bearing flag with <…>.
  # Goal: log enough to identify which command fired, never the secret-bearing value.
  cmd_type=$(printf '%s' "$CMD" | tr '\n\t' '  ' \
    | awk -F'["'"'"']' '{print $1}' \
    | sed -E 's/(-b|-c|-m|-a|-F|--message|--annotate|--file|--body|--body-file|--notes|--notes-file|--title)([[:space:]]+)[^[:space:]"]+/\1\2<…>/g' \
    | head -c 60 | sed -E 's/[[:space:]]+$//')
  printf '%s\t%s\t%s\t%s\n' "$ts" "$verdict" "$cmd_type" "$detail" >> "$LOG_FILE" 2>/dev/null || true
}

# Explicit override (only after user-confirmed false-positive).
# Must be the CLI prefix of the command (first non-whitespace token), NOT
# anywhere in the body — otherwise a commit message that merely mentions the
# variable would silently bypass the scan.
FIRST_LINE=$(printf '%s' "$CMD" | head -n1)
TRIMMED="${FIRST_LINE#"${FIRST_LINE%%[![:space:]]*}"}"
if [[ "$TRIMMED" == "CODEX_SKIP_SECRET_SCAN=1 "* ]]; then
  log_event OVERRIDE "-"
  echo "ℹ️  pre-publish-secret-scan: override active (CODEX_SKIP_SECRET_SCAN=1)" >&2
  exit 0
fi

# Self-scope (defense-in-depth). Codex already narrows most calls via
# settings.json `if:` rules, but the script still keeps publish-only scoping for
# wrapper forms and fallback invocations.
#
# Normal read/search/test commands must not be scanned: this guard is only for
# text the agent is about to write into git/GitHub metadata.
#
# The trigger regex also catches common wrapper forms:
#   - `git -C /path commit -m "..."`     (-C path between `git` and `commit`)
#   - `VAR=value git commit -m "..."`    (leading env-prefix)
#   - `bash -c 'git commit -m "..."'`    (quotes normalized below)
# Reference: https://docs.claude.com/en/docs/claude-code/hooks
TRIGGER_REGEX='(^|[[:space:]&|;`]|=)git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+)?[[:space:]]+(commit[[:space:]]+(-[am]+|-F|--message|--file|--all|-a[[:space:]])|tag[[:space:]]+(-a|-m|--annotate|--message)|branch[[:space:]]+-m|checkout[[:space:]]+-[bB]|switch[[:space:]]+-[cC])|(^|[[:space:]&|;`])gh[[:space:]]+(pr|issue|gist|release)[[:space:]]+(create|edit|comment|review)'
CMD_TRIGGER=$(printf '%s' "$CMD" | tr "'\"" "  ")
if ! [[ "$CMD_TRIGGER" =~ $TRIGGER_REGEX ]]; then
  exit 0
fi

# Pull --body-file / --notes-file / -F content (≤256KB, best-effort)
SCAN="$CMD"
for FLAG in "--body-file" "--notes-file" "-F" "--file"; do
  # `--` ends grep option parsing — needed because $FLAG starts with `--`
  path=$(echo "$CMD" | grep -oE -- "${FLAG}[ =][^ ]+" | head -1 | sed -E "s|^${FLAG}[ =]||; s/^[\"']//; s/[\"']$//")
  if [[ -n "$path" && -f "$path" && $(wc -c < "$path") -lt 262144 ]]; then
    SCAN="$SCAN"$'\n'"$(cat "$path")"
  fi
done

# False-positive whitelist: strip common-legitimate constructs BEFORE pattern match.
SCAN_CLEAN=$(printf '%s\n' "$SCAN" \
  | sed -E 's/(git[[:space:]]+(add|rm|mv|restore))[[:space:]]+[^|&;]*/\1 <PATHS>/g' \
  | grep -vE '^[[:space:]]*(Co-authored-by|Signed-off-by|Reviewed-by|Acked-by|Tested-by|Reported-by):' \
  | sed -E 's/<REDACTED:[^>]+>//g' \
  | sed -E 's/<set via[^>]+>//g' \
  | sed -E 's/<rotated secret[^>]*>//g' \
  | sed -E 's/<chat session>//g' \
  | sed -E 's/(commit|revert|cherry-pick|merge|see|parent|tree|sha)[: ]+[a-f0-9]{7,64}//gi' \
  | sed -E 's/[a-f0-9]{7,12}\.\.[a-f0-9]{7,12}//g')

MATCHES=""
add() { MATCHES="${MATCHES}  • $1"$'\n'; }

echo "$SCAN_CLEAN" | grep -qE 'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+' && add "JWT triplet (eyJ…)"
echo "$SCAN_CLEAN" | grep -qiE '(prod|dev):[a-z-]+-[0-9]+\|[A-Za-z0-9+/=_-]+' && add "Convex deploy key (prod:…|… or dev:…|…)"
echo "$SCAN_CLEAN" | grep -qE 'gh[pousr]_[A-Za-z0-9]{20,}' && add "GitHub PAT (gh[pousr]_…)"
echo "$SCAN_CLEAN" | grep -qE 'AKIA[0-9A-Z]{16}' && add "AWS Access Key (AKIA…)"
echo "$SCAN_CLEAN" | grep -qE '(sk|pk|rk)_(live|test)_[A-Za-z0-9]{20,}' && add "Stripe key"
echo "$SCAN_CLEAN" | grep -qE 'sk-(ant-)?[A-Za-z0-9_-]{20,}' && add "OpenAI/Anthropic API key"
echo "$SCAN_CLEAN" | grep -qE '\$2[aby]?\$[0-9]{2}\$[A-Za-z0-9./]{50,}' && add "bcrypt hash"
echo "$SCAN_CLEAN" | grep -qE '\$argon2(id|i|d)?\$' && add "Argon2 hash"
echo "$SCAN_CLEAN" | grep -qE -- '-----BEGIN [A-Z ]*PRIVATE KEY-----' && add "Private key block"
echo "$SCAN_CLEAN" | grep -qE '[A-Z][A-Z0-9_]*(SECRET|TOKEN|KEY|PASSWORD|PASSWD|HASH|PIN|APIKEY|API_KEY)=[^[:space:]"'"'"']{8,}' && add "ENV-style sensitive assignment (e.g. APP_PROXY_SECRET=…, APP_PIN=…, CONVEX_DEPLOY_KEY=…, *_HASH=…)"

# Hex ≥ 32 chars — only after SHA-context cleanup
echo "$SCAN_CLEAN" | grep -qiE '[a-f0-9]{32,}' && add "Hex string ≥ 32 chars (commit-SHA refs already excluded)"

# Base64-like ≥ 40 chars — require both digit and letter to reduce English-prose FP
b64=$(echo "$SCAN_CLEAN" | grep -oE '[A-Za-z0-9+/_-]{40,}={0,2}' | head -1)
if [[ -n "$b64" ]] && echo "$b64" | grep -qE '[0-9]' && echo "$b64" | grep -qE '[A-Za-z]'; then
  add "Base64-like string ≥ 40 chars (digits + letters)"
fi

if [[ -n "$MATCHES" ]]; then
  # Pattern names only, joined with `|` — no body content (it could contain the secret).
  PATTERN_NAMES=$(printf '%s' "$MATCHES" | sed -E 's/^[[:space:]]*•[[:space:]]*//' | tr '\n' '|' | sed -E 's/\|+$//')
  log_event BLOCK "$PATTERN_NAMES"
  CMD_PREVIEW=$(echo "$CMD" | head -c 500)
  cat >&2 <<EOF
🔒 BLOCKED by pre-publish-secret-scan: possible secret in outgoing git/gh body.

Patterns matched:
$MATCHES
Command (first 500 chars):
  $CMD_PREVIEW

What to do:
  1. Redact the value to a placeholder. Conventions:
       <set via vercel env add VAR_NAME production>
       <set via convex env set VAR_NAME>
       <set via chat session>
       <rotated secret — see chat session>
       <REDACTED:KIND>     (generic)
  2. Surface the raw value to the user in the chat (one-time, for copy-paste).
     Do NOT put it in a file inside the repo.
  3. Re-issue the command with the placeholder.

If this is a genuine false-positive (e.g. a public docs example, test fixture):
  • Surface this block to the user verbatim.
  • Only after the user explicitly says "this is not a secret, proceed" → re-issue the same command with this prefix:
        CODEX_SKIP_SECRET_SCAN=1
  • Never silently bypass. The override is logged.

Reference: ~/.codex/rules/secrets-in-git.md
EOF
  exit 2
fi

exit 0
