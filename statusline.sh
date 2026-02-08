#!/bin/bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)

# Standard ANSI colors
YELLOW='\033[33m'
RED='\033[31m'
RESET='\033[0m'

# Color based on context pressure
if [ "$PCT" -ge 60 ]; then COLOR="$RED"
elif [ "$PCT" -ge 30 ]; then COLOR="$YELLOW"
else COLOR=""; fi

echo -e "[$MODEL] context ${COLOR}${PCT}%${COLOR:+${RESET}}"
