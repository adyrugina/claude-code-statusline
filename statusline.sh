#!/bin/sh
input=$(cat)
model=$(echo "$input" | jq -r '.model.display_name // "unknown"')
used=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
pct=$(printf "%.0f" "$used")

if [ "$pct" -le 30 ]; then
  color=""
  reset=""
elif [ "$pct" -le 60 ]; then
  color="\033[38;5;208m"
  reset="\033[0m"
else
  color="\033[31m"
  reset="\033[0m"
fi
printf "%s | context: %b%s%%%b\n" "$model" "$color" "$pct" "$reset"
