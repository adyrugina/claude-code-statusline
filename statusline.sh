#!/bin/sh
input=$(cat)
model=$(echo "$input" | jq -r '.model.display_name // "unknown"' | sed 's/ (1M context)/ (1M)/g')
used=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
pct=$(printf "%.0f" "$used")
window=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')

# Dynamic thresholds based on context window size
if [ "$window" -ge 1000000 ]; then
  # 1M window: tighter thresholds — quality degrades earlier in absolute terms
  warn=15
  danger=35
else
  # 200K window: standard thresholds
  warn=30
  danger=60
fi

if [ "$pct" -le "$warn" ]; then
  color=""
  reset=""
elif [ "$pct" -le "$danger" ]; then
  color="\033[38;5;208m"
  reset="\033[0m"
else
  color="\033[31m"
  reset="\033[0m"
fi

# Rate limit fields (available after first API response)
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

dim="\033[38;5;240m"
reset_dim="\033[0m"

rate_str=""
if [ -n "$five_pct" ]; then
  rate_str=" ${dim}| now: $(printf '%.0f' "$five_pct")%${reset_dim}"
fi
if [ -n "$week_pct" ]; then
  rate_str="$rate_str ${dim}| week: $(printf '%.0f' "$week_pct")%${reset_dim}"
fi

# Folder path (second line) — show $PWD relative to $HOME
cwd="$PWD"
case "$cwd" in
  "$HOME"*) folder_path="${cwd#$HOME}" ;;
  *) folder_path="$cwd" ;;
esac
[ -z "$folder_path" ] && folder_path="~"

printf "%s | context: %b%s%%%b%s\n%b%s%b\n" \
  "$model" "$color" "$pct" "$reset" "$(printf "%b" "$rate_str")" \
  "$dim" "$folder_path" "$reset_dim"
