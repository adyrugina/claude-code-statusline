#!/bin/sh
input=$(cat)

# ── Pill styling ──────────────────────────────────────────────────────
# A pill = rounded left cap + background-coloured padded text + rounded
# right cap. Caps are Nerd Font Powerline half-circles, emitted as octal
# UTF-8 so no editor can strip them:
#   \356\202\266 = U+E0B6 (left cap)   \356\202\264 = U+E0B4 (right cap)
# Caps are drawn with foreground = the pill's background colour, on the
# default terminal background. The spaces around the text while the
# background colour is active are the padding.
# Colours are SGR parameter strings: "2;R;G;B" (truecolor) or "5;N" (256).
# Truecolor is safe here — Warp sets COLORTERM=truecolor.
PILL_BG="2;66;70;90"   # #42465a — terminal bg (#3a3d4d) lifted half a step, hue kept
PILL_TEXT="5;250"      # light grey text inside pills
WARN_BG="5;208"        # orange background
WARN_FG="5;235"        # dark text for contrast on orange
DANGER_BG="5;196"      # red background
DANGER_FG="5;231"      # white text for contrast on red

# pill <bg-colour> <fg-colour> <text>
pill() {
  printf '\033[38;%sm\356\202\266\033[48;%sm\033[38;%sm%s\033[0m\033[38;%sm\356\202\264\033[0m' \
    "$1" "$1" "$2" "$3" "$1"
}

# ── Input parsing ─────────────────────────────────────────────────────
# One jq pass extracts everything as six lines (blank line = field
# absent). All numeric work happens in jq — `round` instead of shell
# printf %.0f (which breaks under comma-decimal locales), and the reset
# countdown via jq's `now` (epoch seconds, same unit as resets_at).
# Exit status is checked because jq streams: a mid-program type error
# could emit some lines and then die.
vals=$(printf '%s' "$input" | jq -r '
  ((.model.display_name // "unknown") | split(" ")[0] | ascii_downcase),
  (.effort.level // ""),
  (.context_window.used_percentage // 0 | round),
  (.context_window.context_window_size // 200000),
  (.rate_limits.five_hour.used_percentage | if . == null then "" else round end),
  (.rate_limits.five_hour.resets_at | if . == null then "" else (. - now | floor) end),
  (.cost.total_cost_usd | if . == null then "" else (. * 100 | round) end)
' 2>/dev/null) || vals=""

# Bad/missing input, or no jq → one plain pill: never a blank bar,
# never stderr spam, never a half-rendered line
if [ -z "$vals" ]; then
  pill "$PILL_BG" "$PILL_TEXT" "claude"
  printf '\n'
  exit 0
fi

{
  read -r model
  read -r effort
  read -r pct
  read -r window
  read -r rpct
  read -r rem
  read -r cents
} <<EOF
$vals
EOF

# Keep the braces: bash 3.2 mis-parses $var glued to a multibyte char
# (lead byte absorbed into the variable name) if the space is ever removed
[ -n "$effort" ] && model="${model} · ${effort}"

# Dynamic thresholds based on context window size
if [ "$window" -ge 1000000 ]; then
  # 1M window: orange above 15%, red above 35%
  warn=15
  danger=35
else
  # 200K window: orange above 30%, red above 60%
  warn=30
  danger=60
fi

# Context pill background: quiet by default, orange/red as usage climbs
if [ "$pct" -le "$warn" ]; then
  ctx_bg=$PILL_BG
  ctx_fg=$PILL_TEXT
elif [ "$pct" -le "$danger" ]; then
  ctx_bg=$WARN_BG
  ctx_fg=$WARN_FG
else
  ctx_bg=$DANGER_BG
  ctx_fg=$DANGER_FG
fi

# Rate limit pill: hourglass + 5h-window usage + time until the window
# resets (fields only present for subscribers after first API response)
rate_str=""
rate_bg=$PILL_BG
rate_fg=$PILL_TEXT
if [ -n "$rpct" ]; then
  # Same colours as the context pill: orange at 50%, red at 75%
  if [ "$rpct" -ge 75 ]; then
    rate_bg=$DANGER_BG; rate_fg=$DANGER_FG
  elif [ "$rpct" -ge 50 ]; then
    rate_bg=$WARN_BG; rate_fg=$WARN_FG
  fi
  # \342\217\263 = U+23F3 hourglass-with-flowing-sand emoji, octal UTF-8
  # (no space after it — the emoji's double-width cell provides the gap)
  rate_str=$(printf '\342\217\263%s%%' "$rpct")
  if [ -n "$rem" ] && [ "$rem" -gt 0 ]; then
    h=$(( rem / 3600 ))
    m=$(( (rem % 3600) / 60 ))
    if [ "$h" -gt 0 ]; then
      rate_str="${rate_str} · ${h}h$(printf '%02d' "$m")"
    else
      rate_str="${rate_str} · ${m}m"
    fi
  fi
fi

# Estimated API cost pill: what the session would cost at API rates
# (informational on a subscription — never an actual charge). Cost comes
# from jq as integer cents so the shell formats it with pure integer
# arithmetic — no printf %f, which breaks under comma-decimal locales.
cost_str=""
if [ -n "$cents" ]; then
  cost_str=$(printf '$%d.%02d' $(( cents / 100 )) $(( cents % 100 )))
fi

# Layout: four uniform pills — model · context % · rate limits · est. cost
out="$(pill "$PILL_BG" "$PILL_TEXT" "$model")  $(pill "$ctx_bg" "$ctx_fg" "${pct}%")"
[ -n "$rate_str" ] && out="$out  $(pill "$rate_bg" "$rate_fg" "$rate_str")"
[ -n "$cost_str" ] && out="$out  $(pill "$PILL_BG" "$PILL_TEXT" "$cost_str")"
printf '%s\n' "$out"
