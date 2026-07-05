#!/bin/sh
input=$(cat)
model=$(echo "$input" | jq -r '.model.display_name // .model.id // "claude"')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')

# Shorten home directory to ~
home="$HOME"
short_cwd="${cwd/#$home/\~}"

if [ -n "$used" ]; then
    ctx_str=$(printf "ctx:%.0f%%" "$used")
else
    ctx_str="ctx:--"
fi

printf "%s | %s | %s" "$model" "$ctx_str" "$short_cwd"
