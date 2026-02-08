#!/bin/bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
CONTEXT_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size')
USAGE=$(echo "$input" | jq '.context_window.current_usage')

# Colors (true color ANSI)
GREEN='\033[38;2;0;170;0m'
YELLOW='\033[38;2;255;175;0m'
RED='\033[38;2;255;80;80m'
RESET='\033[39m'

get_color() {
    local percent=$1
    if [ "$percent" -le 30 ]; then
        echo ""
    elif [ "$percent" -le 60 ]; then
        echo "$YELLOW"
    else
        echo "$RED"
    fi
}

if [ "$USAGE" != "null" ]; then
    CURRENT_TOKENS=$(echo "$USAGE" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
    PERCENT_USED=$((CURRENT_TOKENS * 100 / CONTEXT_SIZE))
    COLOR=$(get_color "$PERCENT_USED")
    echo -e "$MODEL | context ${COLOR}${PERCENT_USED}%${RESET}"
else
    COLOR=$(get_color 0)
    echo -e "$MODEL | context ${COLOR}0%${RESET}"
fi
